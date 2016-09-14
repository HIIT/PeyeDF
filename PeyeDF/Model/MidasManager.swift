//
// Copyright (c) 2015 Aalto University
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

import Foundation
import Alamofire

/// The fixation data receiver specifies a class that can receive new fixation events
protocol FixationDataDelegate: class {
    
    func receiveNewFixationData(_ newData: [SMIFixationEvent])
}

/// MidasManager is a singleton. It is used to retrieve data from Midas at regular intervals. It keeps a buffer of all retrieved data.
class MidasManager {
    
    /// Returns itself in a shared instance for the whole app
    static let sharedInstance = MidasManager()
    
    /// Address of midas server
    static let kMidasAddress: String = "127.0.0.1"
    
    /// Port of midas server
    static let kMidasPort: String = "8085"
    
    /// How many times we warn user before giving up
    static let kMaxWarnings = 3
    
    /// How many times the user was warned
    fileprivate(set) var warnings = 0
    
    /// Whether there is a midas connection available
    fileprivate(set) var midasAvailable: Bool = false
    
    /// Last valid distance from screen in mm (defaults to 80 cm)
    fileprivate(set) var lastValidDistance: CGFloat = 800.0
    
    /// Last time for last recorded fixation
    fileprivate var lastFixationUnixtime: Int = 0
    
    /// Length of buffer in seconds
    fileprivate let kBufferLength: Int = 1
    
    /// Earliest time that eyes were lost (if they were lost)
    fileprivate var eyesLastSeen: Date?
    
    /// If eyes are lost for this whole period (seconds) an eye lost notification is sent
    let kEyesMaxLostDuration: TimeInterval = 7.0
    
    /// Whether eyes were lost for at least kEyesMaxLostDuration
    fileprivate(set) var eyesLost: Bool = true
    
    /// How often a request is made to midas (seconds)
    fileprivate let kFetchInterval: TimeInterval = 0.500
    
    /// Testing url used by midas
    fileprivate let kTestURL = "http://\(kMidasAddress):\(kMidasPort)/test"
    
    /// Fixation data delegate, to which fixation data will be sent
    fileprivate var fixationDelegate: FixationDataDelegate?
    
    /// SMI-type last timestamp of valid data received
    fileprivate var lastValidSMITime: Int = -1
    
    /// Dominant eye
    lazy fileprivate var dominantEye: Eye = {
        return AppSingleton.getDominantEye()
    }()
    
    /// Fetching of eye tracking events, TO / FROM Midas Manager, and timers related to this activity, are all run on this queue to prevent resource conflicts.
    static let sharedQueue = DispatchQueue(label: "hiit.MidasManager.sharedQueue", attributes: DispatchQueue.Attributes.concurrent)
    
    /// Time to regularly fetch data from Midas
    fileprivate var fetchTimer: Timer?
    
    /// What kind of data we want to get from midas
    fileprivate enum MidasFetchKind {
        /// Eye position X, Y and Z with respect to camera, to know how the user is standing in front of eye tracker
        case eyePosition
        /// Gets an array of all fixations since last fetch
        case fixations
    }
    
    // MARK: - External functions
    
    /// Registers a new fixation delegate, able to receive fixation data. Overwrites the previous one.
    func setFixationDelegate(_ newDelegate: FixationDataDelegate) {
        if fixationDelegate !== newDelegate {
            fixationDelegate = newDelegate
        }
    }
    
    /// Unregisters the current fixation delegate. The one that wants to unregister itself should call this function
    func unsetFixationDelegate(_ oldDelegate: FixationDataDelegate) {
        if fixationDelegate === oldDelegate {
            fixationDelegate = nil
        }
    }
    
    /// Starts fetching data from Midas
    func start() {
        
        // Take action only if midas is currently off
        
        if !midasAvailable {
            // Checks if midas is available, if not doesn't start
            Alamofire.request(kTestURL).responseJSON {
                response in
                
                if response.result.isFailure {
                    self.midasAvailable = false
                    AppSingleton.log.error("Midas is down: \(response.result.error!)")
                    AppSingleton.alertUser("Midas is down", infoText: "Initial connection to midas failed")
                } else if self.fetchTimer == nil {
                    NotificationCenter.default.post(name: PeyeConstants.midasConnectionNotification, object: self, userInfo: ["available": true])
                    self.midasAvailable = true
                    MidasManager.sharedQueue.async {
                        self.fetchTimer = Timer(timeInterval: self.kFetchInterval, target: self, selector: #selector(self.fetchTimerHit(_:)), userInfo: nil, repeats: true)
                        RunLoop.current.add(self.fetchTimer!, forMode: RunLoopMode.commonModes)
                    }
                }
            }
        }
    }
    
    /// Stops fetching data from Midas
    func stop() {
        // take note
        self.midasAvailable = false
        
        // stop timer
        if let timer = fetchTimer {
            MidasManager.sharedQueue.sync {
                    timer.invalidate()
               }
            fetchTimer = nil
        }
        
        // post notification
        NotificationCenter.default.post(name: PeyeConstants.midasConnectionNotification, object: self, userInfo: ["available": false])
    }
    
    /// Sets dominant eye
    func setDominantEye(_ eye: Eye) {
        dominantEye = eye
    }
    
    // MARK: - Internal functions
    
    /// Fetching timer regularly calls this
    @objc fileprivate func fetchTimerHit(_ timer: Timer) {
        MidasManager.sharedQueue.async {
            self.fetchData(PeyeConstants.midasRawNodeName, channels: PeyeConstants.midasRawChannelNames, fetchKind: .eyePosition)
            self.fetchData(PeyeConstants.midasEventNodeName, channels: PeyeConstants.midasEventChannelNames, fetchKind: .fixations)
        }
    }
    
    /// Gets data from the given node, for the given channels
    fileprivate func fetchData(_ nodeName: String, channels: [String], fetchKind: MidasFetchKind) {
        
        let chanString = midasChanString(channels)
        
        let fetchString = "http://\(MidasManager.kMidasAddress):\(MidasManager.kMidasPort)/\(nodeName)/data/{\(chanString), \"time_window\":[\(kBufferLength),\(kBufferLength)]}"
        
        let manager = Alamofire.SessionManager.default
        let midasUrl = URL(string: fetchString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)
        
        let urlRequest = URLRequest(url: midasUrl!)
        let request = manager.request(urlRequest)
        
        request.responseJSON {
            response in
            if response.result.isFailure {
                self.stop()
                AppSingleton.log.error("Error while reading json response from Midas: \(response.result.error!)")
                if self.warnings < MidasManager.kMaxWarnings {
                    AppSingleton.alertUser("Error while reading json response from Midas", infoText: "Message:\n\(response.result.error!)")
                    self.warnings += 1
                }
            } else {
                self.gotData(ofKind: fetchKind, json: JSON(response.result.value!))
            }
        }
    }
 
    /// Called when new data arrives (in fetchdata, Alamofire, hence asynchronously)
    fileprivate func gotData(ofKind fetchKind: MidasFetchKind, json: JSON) {
        switch fetchKind {
        case .eyePosition:
            // send last eye position, if there is actually data
            if json[0]["return"]["timestamp"]["data"].arrayValue.count > 0 {
                let lastPos = SMIEyePosition(fromLastInJSON: json, dominantEye: dominantEye)
                NotificationCenter.default.post(name: PeyeConstants.midasEyePositionNotification, object: self, userInfo: lastPos.asDict())
                
                // check if the entry buffer is all zeros (i.e. eye lost for 1 whole second, assuming a kBufferLength of 1)
                newDataCheck(json)
                
                // save last eye position, if valid
                if lastPos.EyePositionZ > 0 {
                    self.lastValidDistance = CGFloat(lastPos.EyePositionZ)
                }
            }
        case .fixations:
            // fetch fixations which arrived after last recorded fixation and after the user started reading, whichever comes latest
            let minUnixTime = max(lastFixationUnixtime, HistoryManager.sharedManager.readingUnixTime)
            if let (newFixations, lut) = getTimedFixationsAfter(unixtime: minUnixTime, forEye: dominantEye, fromJSON: json) {
                // only send fixations if user is reading
                if HistoryManager.sharedManager.userIsReading {
                    fixationDelegate?.receiveNewFixationData(newFixations)
                }
                lastFixationUnixtime = lut
            }
        }
    }
    
    /// Checks if eye buffer contains old timestamps, or if it is zeroed. If the eyes were lost, checks how long ago they were first lost. If they were lost for long enough, sends a notification.
    /// Sends a notification also if the eyes were previously lost, and are now found
    /// - parameter json: the json object from alamofire
    fileprivate func newDataCheck(_ json: JSON) {
        var eyeString: String
        switch dominantEye {
        case .left:
            eyeString = "left"
        case .right:
            eyeString = "right"
        }
        
        var eyesFound = false
        
        let timestamps = json[0]["return"]["timestamp"]["data"].arrayValue
        let latestTimestamp = timestamps.last!.intValue
        
        // if the latest timestamp is not greater (newer) than latest recorded one, assume eyes were lost, otherwise check for zeroes
        
        if latestTimestamp > lastValidSMITime {
            // check for zeroes
            let Xs = json[0]["return"]["\(eyeString)EyePositionX"]["data"].arrayValue
            let Ys = json[0]["return"]["\(eyeString)EyePositionY"]["data"].arrayValue
            
            // cycle through array and check if all zeroes
            for i in 0 ..< Xs.count {
                if !(Xs[i].doubleValue == 0 && Ys[i].doubleValue == 0) {
                    eyesFound = true
                    break
                }
            }
        }
        
        lastValidSMITime = latestTimestamp
        
        if self.eyesLost && eyesFound {
            self.eyesLost = false
            self.eyesLastSeen = nil
            
            // send found notification
            NotificationCenter.default.post(name: PeyeConstants.eyesAvailabilityNotification, object: self, userInfo: ["available": true])
        } else if !self.eyesLost && !eyesFound {
            // check when eyes were lost before (if so) if period exceeds constant, send notification
            if let prevLostDate = self.eyesLastSeen {
                let shiftedDate = prevLostDate.addingTimeInterval(kEyesMaxLostDuration)
                // if the current date comes after the shifted date, send notification
                if Date().compare(shiftedDate) == ComparisonResult.orderedDescending {
                    
                        self.eyesLost = true
                    NotificationCenter.default.post(name: PeyeConstants.eyesAvailabilityNotification, object: self, userInfo: ["available": false])
                }
            } else {
                self.eyesLastSeen = Date()
            }
        }
    }
}

/// Given a list of channels, generates a string (which should be later concatenated in a url, hence needs to be converted using stringByAddingPercentEncoding) for the midas url request.
func midasChanString(_ listOfChannels: [String]) -> String {
    // example of a request url:
    // http://127.0.0.1:8080/sample_eyestream/data/{"channels":["x", "y"],"time_window":[0.010, 0.010]}
    
    var fromChannels = listOfChannels
    let prefix = "\"channels\":["
    let suffix = "]"
    
    let firstChan = fromChannels.remove(at: 0)
    var outString = prefix + "\"" + firstChan + "\""
    
    for chan in fromChannels {
        outString += ", \"" + chan + "\""
    }
    
    return outString + suffix
}

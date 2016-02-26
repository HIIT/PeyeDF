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
    
    func receiveNewFixationData(newData: [SMIFixationEvent])
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
    private(set) var warnings = 0
    
    /// Whether there is a midas connection available
    private(set) var midasAvailable: Bool = false
    
    /// Last valid distance from screen in mm (defaults to 80 cm)
    private(set) var lastValidDistance: CGFloat = 800.0
    
    /// Last time for last recorded fixation
    private var lastFixationUnixtime: Int = 0
    
    /// Length of buffer in seconds
    private let kBufferLength: Int = 1
    
    /// Earliest time that eyes were lost (if they were lost)
    private var eyesLastSeen: NSDate?
    
    /// If eyes are lost for this whole period (seconds) an eye lost notification is sent
    let kEyesMaxLostDuration: NSTimeInterval = 7.0
    
    /// Whether eyes were lost for at least kEyesMaxLostDuration
    private(set) var eyesLost: Bool = true
    
    /// How often a request is made to midas (seconds)
    private let kFetchInterval: NSTimeInterval = 0.500
    
    /// Testing url used by midas
    private let kTestURL = "http://\(kMidasAddress):\(kMidasPort)/test"
    
    /// Fixation data delegate, to which fixation data will be sent
    private var fixationDelegate: FixationDataDelegate?
    
    /// SMI-type last timestamp of valid data received
    private var lastValidSMITime: Int = -1
    
    /// Dominant eye
    lazy private var dominantEye: Eye = {
        return AppSingleton.getDominantEye()
    }()
    
    /// Fetching of eye tracking events, TO / FROM Midas Manager, and timers related to this activity, are all run on this queue to prevent resource conflicts.
    static let sharedQueue = dispatch_queue_create("hiit.MidasManager.sharedQueue", DISPATCH_QUEUE_CONCURRENT)
    
    /// Time to regularly fetch data from Midas
    private var fetchTimer: NSTimer?
    
    /// What kind of data we want to get from midas
    private enum MidasFetchKind {
        /// Eye position X, Y and Z with respect to camera, to know how the user is standing in front of eye tracker
        case EyePosition
        /// Gets an array of all fixations since last fetch
        case Fixations
    }
    
    // MARK: - External functions
    
    /// Registers a new fixation delegate, able to receive fixation data. Overwrites the previous one.
    func setFixationDelegate(newDelegate: FixationDataDelegate) {
        if fixationDelegate !== newDelegate {
            fixationDelegate = newDelegate
        }
    }
    
    /// Unregisters the current fixation delegate. The one that wants to unregister itself should call this function
    func unsetFixationDelegate(oldDelegate: FixationDataDelegate) {
        if fixationDelegate === oldDelegate {
            fixationDelegate = nil
        }
    }
    
    /// Starts fetching data from Midas
    func start() {
        
        // Take action only if midas is currently off
        
        if !midasAvailable {
            // Checks if midas is available, if not doesn't start
            Alamofire.request(.GET, kTestURL).responseJSON {
                response in
                
                if response.result.isFailure {
                    self.midasAvailable = false
                    AppSingleton.log.error("Midas is down: \(response.result.error!)")
                    AppSingleton.alertUser("Midas is down", infoText: "Initial connection to midas failed")
                } else if self.fetchTimer == nil {
                    NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.midasConnectionNotification, object: self, userInfo: ["available": true])
                    self.midasAvailable = true
                    dispatch_sync(MidasManager.sharedQueue) {
                        self.fetchTimer = NSTimer(timeInterval: self.kFetchInterval, target: self, selector: "fetchTimerHit:", userInfo: nil, repeats: true)
                        NSRunLoop.currentRunLoop().addTimer(self.fetchTimer!, forMode: NSRunLoopCommonModes)
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
            dispatch_sync(MidasManager.sharedQueue) {
                    timer.invalidate()
               }
            fetchTimer = nil
        }
        
        // post notification
        NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.midasConnectionNotification, object: self, userInfo: ["available": false])
    }
    
    /// Sets dominant eye
    func setDominantEye(eye: Eye) {
        dominantEye = eye
    }
    
    // MARK: - Internal functions
    
    /// Fetching timer regularly calls this
    @objc private func fetchTimerHit(timer: NSTimer) {
        dispatch_async(MidasManager.sharedQueue) {
            self.fetchData(PeyeConstants.midasRawNodeName, channels: PeyeConstants.midasRawChannelNames, fetchKind: .EyePosition)
            self.fetchData(PeyeConstants.midasEventNodeName, channels: PeyeConstants.midasEventChannelNames, fetchKind: .Fixations)
        }
    }
    
    /// Gets data from the given node, for the given channels
    private func fetchData(nodeName: String, channels: [String], fetchKind: MidasFetchKind) {
        
        let chanString = midasChanString(fromChannels: channels)
        
        let fetchString = "http://\(MidasManager.kMidasAddress):\(MidasManager.kMidasPort)/\(nodeName)/data/{\(chanString), \"time_window\":[\(kBufferLength),\(kBufferLength)]}"
        
        let manager = Alamofire.Manager.sharedInstance
        let midasUrl = NSURL(string: fetchString.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!)
        
        let urlRequest = NSURLRequest(URL: midasUrl!)
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
    private func gotData(ofKind fetchKind: MidasFetchKind, json: JSON) {
        switch fetchKind {
        case .EyePosition:
            // send last eye position, if there is actually data
            if json[0]["return"]["timestamp"]["data"].arrayValue.count > 0 {
                let lastPos = SMIEyePosition(fromLastInJSON: json, dominantEye: dominantEye)
                NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.midasEyePositionNotification, object: self, userInfo: lastPos.asDict())
                
                // check if the entry buffer is all zeros (i.e. eye lost for 1 whole second, assuming a kBufferLength of 1)
                newDataCheck(json)
                
                // save last eye position, if valid
                if lastPos.EyePositionZ > 0 {
                    self.lastValidDistance = CGFloat(lastPos.EyePositionZ)
                }
            }
        case .Fixations:
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
    private func newDataCheck(json: JSON) {
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
            NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.eyesAvailabilityNotification, object: self, userInfo: ["available": true])
        } else if !self.eyesLost && !eyesFound {
            // check when eyes were lost before (if so) if period exceeds constant, send notification
            if let prevLostDate = self.eyesLastSeen {
                let shiftedDate = prevLostDate.dateByAddingTimeInterval(kEyesMaxLostDuration)
                // if the current date comes after the shifted date, send notification
                if NSDate().compare(shiftedDate) == NSComparisonResult.OrderedDescending {
                    
                        self.eyesLost = true
                    NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.eyesAvailabilityNotification, object: self, userInfo: ["available": false])
                }
            } else {
                self.eyesLastSeen = NSDate()
            }
        }
    }
}

/// Given a list of channels, generates a string (which should be later concatenated in a url, hence needs to be converted using stringByAddingPercentEncoding) for the midas url request.
func midasChanString(var fromChannels listOfChannels: [String]) -> String {
    // example of a request url:
    // http://127.0.0.1:8080/sample_eyestream/data/{"channels":["x", "y"],"time_window":[0.010, 0.010]}
    
    let prefix = "\"channels\":["
    let suffix = "]"
    
    let firstChan = listOfChannels.removeAtIndex(0)
    var outString = prefix + "\"" + firstChan + "\""
    
    for chan in listOfChannels {
        outString += ", \"" + chan + "\""
    }
    
    return outString + suffix
}

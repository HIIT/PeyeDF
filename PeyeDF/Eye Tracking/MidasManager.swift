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


/// MidasManager provides eye tracking data by using Midas (adopts the EyeDataProvider). It is used to retrieve data from Midas at regular intervals. It keeps a buffer of all retrieved data.
class MidasManager: EyeDataProvider {
    
    // MARK: - Constants
    
    /// Convenience inner class to store constants
    class Constants {
        
        /// Midas raw channel numbers
        enum rawChanNumbers: Int {
            case timestamp = 0, leftGazeX, leftGazeY, leftDiam, leftEyePositionX, leftEyePositionY, leftEyePositionZ, rightGazeX, rightGazeY, rightDiam, rightEyePositionX, rightEyePositionY, rightEyePositionZ
        }
        
        /// Midas event channel numbers
        enum eventChanNumber: Int {
            case eye = 0, startTime, endTime, duration, positionX, positionY, marcotime
        }
        
        /// Name of the midas node containing raw (gaze) data
        static let rawNodeName = "raw_eyestream"
        
        /// Name of the midas node containing event data
        static let eventNodeName = "event_eyestream"
        
        /// List of all channel names in raw stream, in order
        static let rawChannelNames = ["timestamp", "leftGazeX", "leftGazeY", "leftDiam", "leftEyePositionX", "leftEyePositionY", "leftEyePositionZ", "rightGazeX", "rightGazeY", "rightDiam", "rightEyePositionX", "rightEyePositionY", "rightEyePositionZ"]
        
        /// List of all channel names in event stream, in order
        static let eventChannelNames = ["eye", "startTime", "endTime", "duration", "positionX", "positionY", "marcotime"]
    }
    
    /// What kind of data we want to get from midas
    fileprivate enum MidasFetchKind {
        /// Eye position X, Y and Z with respect to camera, to know how the user is standing in front of eye tracker
        case eyePosition
        /// Gets an array of all fixations since last fetch
        case fixations
    }
    
    /// How many times we warn user before giving up
    static let kMaxWarnings = 3
    
    /// Length of buffer in seconds
    fileprivate let kBufferLength: Int = 1
        
    /// How often a request is made to midas (seconds)
    fileprivate let kFetchInterval: TimeInterval = 0.500
    
    /// Fetching of eye tracking events, TO / FROM Midas Manager, and timers related to this activity, are all run on this queue to prevent resource conflicts.
    static let sharedQueue = DispatchQueue(label: "hiit.MidasManager.sharedQueue", attributes: DispatchQueue.Attributes.concurrent)

    // MARK: - Instance variables
    
    /// How many times the user was warned
    fileprivate(set) var warnings = 0
    
    /// Whether there is a midas connection available
    fileprivate(set) var midasAvailable: Bool = false
    
    /// Tells others whether we are available (protocol implementation)
    var available: Bool { get {
        return midasAvailable
    } }
    
    /// Last valid distance from screen in mm (defaults to 80 cm)
    fileprivate(set) var lastValidDistance: CGFloat = 800.0
    
    /// Last time for last recorded fixation
    fileprivate var lastFixationUnixtime: Int = 0
    
    /// Earliest time that eyes were lost (if they were lost)
    fileprivate var eyesLastSeen: Date?
    
    /// Whether eyes were lost for at least PeyeConstants.eyesMaxLostDuration
    fileprivate(set) var eyesLost: Bool = true
    
    /// Fixation data delegate, to which fixation data will be sent
    var fixationDelegate: FixationDataDelegate?
    
    /// SMI-type last timestamp of valid data received
    fileprivate var lastValidSMITime: Int = -1
    
    /// Time to regularly fetch data from Midas
    fileprivate var fetchTimer: Timer?
    
    // MARK: - External functions
        
    /// Starts fetching data from Midas
    func start() {
        
        // Take action only if midas is currently off
        
        if !midasAvailable {
        
            // Checks if midas is available, if not doesn't start
            MidasSession.test() {
                success in
                
                self.midasAvailable = success
                self.eyeConnectionChange(available: success)
                
                if !success {
                    AppSingleton.alertUser("Midas is down", infoText: "Initial connection to midas failed")
                } else if self.fetchTimer == nil {
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
        eyeConnectionChange(available: false)
    }
    
    // MARK: - Internal functions
    
    /// Fetching timer regularly calls this
    @objc fileprivate func fetchTimerHit(_ timer: Timer) {
        MidasManager.sharedQueue.async {
            self.fetchData(Constants.rawNodeName, channels: Constants.rawChannelNames, fetchKind: .eyePosition)
            self.fetchData(Constants.eventNodeName, channels: Constants.eventChannelNames, fetchKind: .fixations)
        }
    }
    
    /// Gets data from the given node, for the given channels
    fileprivate func fetchData(_ nodeName: String, channels: [String], fetchKind: MidasFetchKind) {

        let chanString = midasChanString(channels)
        let suffix = "\(nodeName)/data/{\(chanString), \"time_window\":[\(kBufferLength),\(kBufferLength)"
        
        MidasSession.fetch(suffix: suffix) {
            json, error in
            
            guard let json = json else {
                self.stop()
                if self.warnings < MidasManager.kMaxWarnings {
                    if let error = error {
                        AppSingleton.alertUser("Error while reading json response from Midas", infoText: "Error:\n\(error).")
                    } else {
                        AppSingleton.alertUser("Failed to retrieve data from Midas.")
                    }
                    self.warnings += 1
                }
                return
            }
            
            self.gotData(ofKind: fetchKind, json: json)

        }
    }
 
    /// Called when new data arrives (in fetchdata, Alamofire, hence asynchronously)
    fileprivate func gotData(ofKind fetchKind: MidasFetchKind, json: JSON) {
        switch fetchKind {
        case .eyePosition:
            // send last eye position, if there is actually data
            if json[0]["return"]["timestamp"]["data"].arrayValue.count > 0 {
                
                // send last raw eye position
                let lastPos = RawEyePosition(fromLastInMidasJSON: json, dominantEye: AppSingleton.dominantEye)
                sendLastRaw(lastPos)
                
                // check if the entry buffer is all zeros (i.e. eye lost for 1 whole second, assuming a buffer length of 1)
                newDataCheck(json)
                
                // save last eye position, if valid
                if lastPos.EyePositionZ > 0 {
                    self.lastValidDistance = CGFloat(lastPos.EyePositionZ)
                }
            }
        case .fixations:
            // fetch fixations which arrived after last recorded fixation and after the user started reading, whichever comes latest
            let minUnixTime = max(lastFixationUnixtime, HistoryManager.sharedManager.readingUnixTime)
            if let (newFixations, lut) = getTimedFixationsAfter(fromMidasJSON: json, unixtime: minUnixTime, forEye: AppSingleton.dominantEye) {
                // only send fixations if user is reading
                if HistoryManager.sharedManager.userIsReading {
                    sendFixations(newFixations)
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
        switch AppSingleton.dominantEye {
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
            eyeStateChange(available: true)
        } else if !self.eyesLost && !eyesFound {
            // check when eyes were lost before (if so) if period exceeds constant, send notification
            if let prevLostDate = self.eyesLastSeen {
                let shiftedDate = prevLostDate.addingTimeInterval(PeyeConstants.eyesMaxLostDuration)
                // if the current date comes after the shifted date, send notification
                if Date().compare(shiftedDate) == ComparisonResult.orderedDescending {
                    self.eyesLost = true
                    eyeStateChange(available: false)
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

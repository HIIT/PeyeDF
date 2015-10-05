//
//  MidasManager.swift
//  PeyeDF
//
//  Created by Marco Filetti on 15/09/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Alamofire

/// The fixation data receiver specifies a class that can receive new fixation events
protocol FixationDataDelegate: class {
    
    func receiveNewFixationData(newData: [SMIFixationEvent])
}

/// MidasManager is a singleton. It is used to retrieve data from Midas at regular intervals. It keeps a buffer of all retrieved data.
class MidasManager {
    
    /// Returns itself
    static let sharedInstance = MidasManager()
    
    /// Address of midas server
    static let kMidasAddress: String = "127.0.0.1"
    
    /// Port of midas server
    static let kMidasPort: String = "8085"
    
    /// Whether there is a midas connection available
    private var midasAvailable: Bool = false
    
    /// Last SMI timestamp for last recorded fixation
    private var lastFixationStartTime: Int = 0
    
    /// Length of buffer in seconds
    private let kBufferLength: Int = 1
    
    /// How often a request is made to midas (seconds)
    private let kFetchInterval: NSTimeInterval = 0.5
    
    /// Testing url used by midas
    private let kTestURL = "http://\(kMidasAddress):\(kMidasPort)/test"
    
    /// Fixation data delegate, to which fixation data will be sent
    private var fixationDelegate: FixationDataDelegate?
    
    /// Dominant eye
    private var dominantEye: Eye!
    
    /// Fetching of eye tracking events, TO / FROM Midas Manager, and timers related to this activity, are all run on this queue to prevent resource conflicts.
    /// writing of eye tracking events blocks the queue, reading does not.
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
        dominantEye = AppSingleton.getDominantEye()
        
        // Take action only if midas is currently off
        
        if !midasAvailable {
            // Checks if midas is available, if not doesn't start
            Alamofire.request(.GET, kTestURL).responseJSON {
                _, _, response in
                
                if response.isFailure {
                    self.midasAvailable = false
                    AppSingleton.log.error("Midas is down: \(response.debugDescription)")
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
        NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.midasConnectionNotification, object: self, userInfo: ["available": false])
        
        // stop timer
        if let timer = fetchTimer {
            dispatch_sync(MidasManager.sharedQueue) {
                    timer.invalidate()
               }
            fetchTimer = nil
        }
    }
    
    /// Tells whether midas is available
    func isMidasAvailable() -> Bool {
        return midasAvailable
    }
    
    /// Sets dominant eye
    func setDominantEye(eye: Eye!) {
        dominantEye = eye
    }
    
    // MARK: - Internal functions
    
    /// Fetching timer regularly calls this
    @objc private func fetchTimerHit(timer: NSTimer) {
        fetchData(PeyeConstants.midasRawNodeName, channels: PeyeConstants.midasRawChannelNames, fetchKind: .EyePosition)
        fetchData(PeyeConstants.midasEventNodeName, channels: PeyeConstants.midasEventChannelNames, fetchKind: .Fixations)
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
            _, _, response in
            if response.isFailure {
                self.stop()
                AppSingleton.log.error("Error while reading json response from Midas: \(response.debugDescription)")
                AppSingleton.alertUser("Error while reading json response from Midas", infoText: "Message from midas:\n\(response.debugDescription)")
            } else {
                self.gotData(ofKind: fetchKind, json: JSON(response.value!))
            }
        }
    }
 
    /// Called when new data arrives (in fetchdata, Alamofire, hence asynchronously)
    private func gotData(ofKind fetchKind: MidasFetchKind, json: JSON) {
        switch fetchKind {
        case .EyePosition:
            let lastPos = SMIEyePosition(fromLastInJSON: json, dominantEye: dominantEye)
            NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.midasEyePositionNotification, object: self, userInfo: lastPos.asDict())
        case .Fixations:
            let newFixations = getAllFixationsAfter(lastFixationStartTime, forEye: dominantEye, fromJSON: json)
            if let newFixations = newFixations {
                lastFixationStartTime = newFixations.last!.startTime
                fixationDelegate?.receiveNewFixationData(newFixations)
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

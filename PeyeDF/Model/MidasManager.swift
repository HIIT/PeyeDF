//
//  MidasManager.swift
//  PeyeDF
//
//  Created by Marco Filetti on 15/09/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Alamofire


/// MidasManager is a singleton. It is used to retrieve data from Midas at regular intervals. It keeps a buffer of all retrieved data.
class MidasManager {
    
    /// Returns itself
    static let sharedInstance = MidasManager()
    
    /// Whether there is a midas connection available
    var midasAvailable: Bool = false
    
    /// Length of buffer in seconds
    private let kBufferLength: Int = 10
    
    /// How often a request is made to midas (seconds)
    private let kFetchInterval: NSTimeInterval = 5.0
    
    /// Testing url used by midas
    private let kTestURL = "http://127.0.0.1:8080/test"
    
    /// Fetching of eye tracking events, TO / FROM Midas Manager, and timers related to this activity, are all run on this queue to prevent resource conflicts.
    /// writing of eye tracking events blocks the queue, reading does not.
    static let sharedQueue = dispatch_queue_create("hiit.PeyeDF.MidasManager.sharedQueue", DISPATCH_QUEUE_CONCURRENT)
    
    /// Time to regularly fetch data from Midas
    private var fetchTimer: NSTimer?
    
    /// Starts fetching data from Midas
    func start() {
        /// Checks if midas is available, if not doesn't start
        Alamofire.request(.GET, kTestURL).responseJSON {
            _, _, JSON in
            
            if JSON.isFailure {
                self.midasAvailable = false
                AppSingleton.log.error("Midas is down: \(JSON.debugDescription)")
            } else if self.fetchTimer == nil {
                self.midasAvailable = true
                dispatch_sync(MidasManager.sharedQueue) {
                    self.fetchTimer = NSTimer(timeInterval: self.kFetchInterval, target: self, selector: "fetchTimerHit:", userInfo: nil, repeats: true)
                    NSRunLoop.currentRunLoop().addTimer(self.fetchTimer!, forMode: NSRunLoopCommonModes)
                }
            }
        }
    }
    
    /// Stops fetching data from Midas
    func stop() {
        if let timer = fetchTimer {
            dispatch_sync(MidasManager.sharedQueue) {
                    timer.invalidate()
               }
            fetchTimer = nil
        }
    }
    
    /// Fetching timer regularly calls this
    @objc private func fetchTimerHit(timer: NSTimer) {
        
    }
    
    func fiveSeconds() {
        // get last 5 seconds of data
        
        let fetchString = "http://127.0.0.1:8080/sample_eyestream/data/{\"channels\":[\"x\", \"y\"], \"time_window\":[\(kBufferLength),\(kBufferLength)]}"
        
        let manager = Alamofire.Manager.sharedInstance
        let midasUrl = NSURL(string: fetchString.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!)
        
        let urlRequest = NSURLRequest(URL: midasUrl!)
        let request = manager.request(urlRequest)
        
        request.responseJSON {
            _, _, JSON in
            if JSON.isFailure {
                AppSingleton.log.error("Error while reading json response from Midas: \(JSON.debugDescription)")
            } else {
                AppSingleton.log.debug("Data got")
                print(JSON.description)
            }
        }
    }
    
}
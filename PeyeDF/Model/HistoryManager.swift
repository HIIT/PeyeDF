//
//  HistoryManager.swift
//  PeyeDF
//
//  Created by Marco Filetti on 26/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

// The history manager is a singleton and keeps track of all history events happening trhough the application.
// This includes, for example, timers which trigger at predefined intervals (such as closing events after a
// specific amount of time has passed, assuming that the user went away from keyboard).
// See https://github.com/HIIT/PeyeDF/wiki/Data-Format for more information

import Foundation
import Alamofire

class HistoryManager {
    
    /// Returns a shared instance of this class. This is the designed way of accessing the history manager.
    static let sharedManager = HistoryManager()
    
    /// The timer that fires when we assume that the user starts reading. Pass the DocumentWindowController as the userInfo object.
    private var entryTimer: NSTimer?
    
    /// The timer that fires after a certain amount of time passed, and generates an "exit event"
    private var exitTimer: NSTimer?
    
    
    /// The GDC queue in which all timers are created / destroyed (to prevent potential memory leaks, the all run here)
    private let timerQueue = dispatch_queue_create("hiit.PeyeDF.HistoryManager.timerQueue", DISPATCH_QUEUE_SERIAL)
    
    private init() {
        
    }
    
    // MARK: - External functions
    
    /// Send an "Event" to DiMe
    func sendToDiMe(event: Event) {
        sendDictToDime(event.json.dictionaryObject!)
    }
    
    /// Send a "Dictionariable" to DiMe
    func sendToDiMe(dictionariable: Dictionariable) {
        sendDictToDime(dictionariable.getDict())
    }
    
    // MARK: - Internal functions
    
    private func sendDictToDime(dictionaryObject: [String: AnyObject]) {
        
        let server_url: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefServerURL) as! String
        let user: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefServerUserName) as! String
        let password: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefServerPassword) as! String
        
        let credentialData = "\(user):\(password)".dataUsingEncoding(NSUTF8StringEncoding)!
        let base64Credentials = credentialData.base64EncodedStringWithOptions(nil)
        
        let headers = ["Authorization": "Basic \(base64Credentials)"]
        
        var error = NSErrorPointer()
        let options = NSJSONWritingOptions.PrettyPrinted

        let jsonData = NSJSONSerialization.dataWithJSONObject(dictionaryObject, options: options, error: error)
        
        if jsonData == nil {
            AppSingleton.log.error("Error while deserializing json! This should never happen. \(error)")
            return
        }
        
        Alamofire.request(Alamofire.Method.POST, server_url + "/data/event", parameters: dictionaryObject, encoding: Alamofire.ParameterEncoding.JSON, headers: headers).responseJSON {
            _, _, JSON, requestError in
            if let error = requestError {
                AppSingleton.log.error("Error while reading json response from DiMe: \(requestError)")
            } else {
                AppSingleton.log.debug("Request sent and received: \n" + JSON!.description)
            }
        }
    }
    
    private func preparation(documentWindow: DocumentWindowController) {
        let exception = NSException(
            name: "Not implemented!",
            reason: "Just an example",
            userInfo: nil
        )
        exception.raise()
        exitEvent()
        dispatch_sync(timerQueue) {
            self.entryTimer = NSTimer(timeInterval: PeyeConstants.minReadTime, target: self, selector: "entryTimerFire:", userInfo: documentWindow, repeats: false)
            NSRunLoop.currentRunLoop().addTimer(self.entryTimer!, forMode: NSRunLoopCommonModes)
        }
    }
    
    /// The user has moved away, send current status (if any) and invalidate timer
    private func exitEvent() {
        if let timer = self.entryTimer {
            dispatch_sync(timerQueue) {
                    timer.invalidate()
               }
            self.entryTimer = nil
        }
    }
    
    /// The document has been "seen" long enough, request information
    @objc private func entryTimerFire(entryTimer: NSTimer) {
        let docWindow = entryTimer.userInfo as! DocumentWindowController
        
        // retrieve status here
    }
    
}

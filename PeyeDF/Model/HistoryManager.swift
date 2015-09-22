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
    
    /// The reading event that will be sent at an exit event
    private var currentReadingEvent: ReadingEvent?
    
    /// The GDC queue in which all timers are created / destroyed (to prevent potential memory leaks, they all run here)
    private let timerQueue = dispatch_queue_create("hiit.PeyeDF.HistoryManager.timerQueue", DISPATCH_QUEUE_SERIAL)
    
    private init() {
        
    }
    
    // MARK: - External functions - entry / exit events
    
    /// Tells the history manager that something new is happened. The history manager check if the sender is a window in front (main window)
    ///
    /// - parameter documentWindow: The window controller that is sending the message
    func entry(documentWindow: DocumentWindowController) {
        if let window = documentWindow.window {
            if window.mainWindow {
                preparation(documentWindow)
            }
        }
    }
    
    /// Tells the history manager to close the current event (we switched focus, or something similar)
    func exit(documentWindow: DocumentWindowController) {
        exitEvent(nil)
    }
    
    // MARK: - External functions - direct sending
    
    /// Send an "Event" to DiMe
    func sendToDiMe(event: Event) {
        sendDictToDime(event.json.dictionaryObject!)
    }
    
    /// Send a "Dictionariable" to DiMe
    func sendToDiMe(dictionariable: Dictionariable) {
        sendDictToDime(dictionariable.getDict())
    }
    
    // MARK: - Internal functions
    
    /// Send the given dictionary to DiMe (assumed to be in correct form due to the use of public callers of this method)
    private func sendDictToDime(dictionaryObject: [String: AnyObject]) {
        
        let server_url: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefServerURL) as! String
        let user: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefServerUserName) as! String
        let password: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefServerPassword) as! String
        
        let credentialData = "\(user):\(password)".dataUsingEncoding(NSUTF8StringEncoding)!
        let base64Credentials = credentialData.base64EncodedStringWithOptions([])
        
        let headers = ["Authorization": "Basic \(base64Credentials)"]
        
        let error = NSErrorPointer()
        let options = NSJSONWritingOptions.PrettyPrinted

        let jsonData: NSData?
        do {
            jsonData = try NSJSONSerialization.dataWithJSONObject(dictionaryObject, options: options)
        } catch let error1 as NSError {
            error.memory = error1
            jsonData = nil
        }
        
        if jsonData == nil {
            AppSingleton.log.error("Error while deserializing json! This should never happen. \(error)")
            return
        }
        
        Alamofire.request(Alamofire.Method.POST, server_url + "/data/event", parameters: dictionaryObject, encoding: Alamofire.ParameterEncoding.JSON, headers: headers).responseJSON {
            _, _, response in
            if response.isFailure {
                AppSingleton.log.error("Error while reading json response from DiMe: \(response.debugDescription)")
            } else {
                AppSingleton.log.debug("Data pushed to DiMe")
                // JSON(response.value!) to see what dime replied
            }
        }
        
        
    }
    
    /// Starts the "entry timer" and sets up references to the current window
    private func preparation(documentWindow: DocumentWindowController) {
        exitEvent(nil)
        dispatch_sync(timerQueue) {
            self.entryTimer = NSTimer(timeInterval: PeyeConstants.minReadTime, target: self, selector: "entryTimerFire:", userInfo: documentWindow, repeats: false)
            NSRunLoop.currentRunLoop().addTimer(self.entryTimer!, forMode: NSRunLoopCommonModes)
        }
    }
    
    /// The document has been "seen" long enough, request information and prepare second (exit) timer
    @objc private func entryTimerFire(entryTimer: NSTimer) {
        let docWindow = entryTimer.userInfo as! DocumentWindowController
        self.entryTimer = nil
        
        // retrieve status
        self.currentReadingEvent = docWindow.getCurrentStatus()
        
        // TODO: remove this debugging trap
        if let _ = self.exitTimer {
            let exception = NSException(name: "This should never happen!", reason: nil, userInfo: nil)
            exception.raise()
        }
        
        // prepare exit timer, which will fire when the user is inactive long enough (or will be canceled if there is another exit event).
        if let _ = self.currentReadingEvent {
            dispatch_sync(timerQueue) {
                self.exitTimer = NSTimer(timeInterval: PeyeConstants.maxReadTime, target: self, selector: "exitEvent:", userInfo: nil, repeats: false)
                NSRunLoop.currentRunLoop().addTimer(self.exitTimer!, forMode: NSRunLoopCommonModes)
            }
        }
    }
    
    /// The user has moved away, send current status (if any) and invalidate timer
    @objc private func exitEvent(exitTimer: NSTimer?) {
        if let timer = self.entryTimer {
            dispatch_sync(timerQueue) {
                    timer.invalidate()
               }
            self.entryTimer = nil
        }
        if let timer = self.exitTimer {
            dispatch_sync(timerQueue) {
                    timer.invalidate()
               }
            self.exitTimer = nil
        }
        if let currentStatus = self.currentReadingEvent {
            currentStatus.setEnd(NSDate())
            sendToDiMe(currentStatus as Event)
            self.currentReadingEvent = nil
        }
    }
    
}

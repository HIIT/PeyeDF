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

/// The HistoryManager tracks all user activity, including fixations from eye tracking
class HistoryManager: FixationDataDelegate {
    
    /// Returns a shared instance of this class. This is the designed way of accessing the history manager.
    static let sharedManager = HistoryManager()
    
    /// The timer that fires when we assume that the user starts reading. Pass the DocumentWindowController as the userInfo object.
    private var entryTimer: NSTimer?
    
    /// The timer that fires after a certain amount of time passed, and generates an "exit event"
    private var exitTimer: NSTimer?
    
    /// The GDC queue in which all timers are created / destroyed (to prevent potential memory leaks, they all run here)
    private let timerQueue = dispatch_queue_create("hiit.PeyeDF.HistoryManager.timerQueue", DISPATCH_QUEUE_SERIAL)
    
    /// Is true if there is a connection to DiMe, and can be used
    private(set) var dimeAvailable: Bool = false

    // MARK: - History tracking fields
    
    /// The reading event that will be sent at an exit event
    private var currentReadingEvent: ReadingEvent?
    
    /// A boolean indicating that the user is (probably) reading. Essentially, it means we are after entry timer but before exit timer (or exit event).
    private(set) var userIsReading = false
    
    /// The current thing the user is probably looking at (MyPDFReader instance), which will be used to convert screen to page coordinates
    private var currentEyeReceiver: ScreenToPageConverter?
    
    /// A dictionary, one entry per page (indexed by page number) containing all page eye tracking data
    private var currentEyeData = [Int: PageEyeData]()
    
    // MARK: - External functions
    
    /// Attempts to connect to dime. Sends a notification if we succeeded / failed
    func dimeConnect() {
        let server_url: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerURL) as! String
        let user: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerUserName) as! String
        let password: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerPassword) as! String
        
        let credentialData = "\(user):\(password)".dataUsingEncoding(NSUTF8StringEncoding)!
        let base64Credentials = credentialData.base64EncodedStringWithOptions([])
        
        let headers = ["Authorization": "Basic \(base64Credentials)"]
        
        let dictionaryObject = ["test": "test"]
        
        Alamofire.request(Alamofire.Method.POST, server_url + "/ping", parameters: dictionaryObject, encoding: Alamofire.ParameterEncoding.JSON, headers: headers).responseJSON {
            _, _, response in
            if response.isFailure {
                // connection failed
                AppSingleton.alertUser("Error while communcating with dime. Dime has now been disconnected", infoText: "Message from dime:\n\(response.debugDescription)")
                
                self.dimeConnectState(false)
            } else {
                // succesfully connected
                self.dimeConnectState(true)
            }
        }
    }
    
    /// Tells the history manager that something new is happened. The history manager check if the sender is a window in front (main window)
    ///
    /// - parameter documentWindow: The window controller that is sending the message
    func entry(documentWindow: DocumentWindowController) {
        if let window = documentWindow.window {
            if window.mainWindow {
                // if we are tracking eyes (using midas), make sure eyes are available before starting
                if MidasManager.sharedInstance.midasAvailable {
                    if !MidasManager.sharedInstance.eyesLost {
                        preparation(documentWindow)
                    }
                } else {
                    preparation(documentWindow)
                }
            }
        }
    }
    
    /// Tells the history manager to close the current event (we switched focus, or something similar)
    func exit(documentWindow: DocumentWindowController) {
        exitEvent(nil)
    }
    
    // MARK: - Protocol implementation
    
    func receiveNewFixationData(newData: [SMIFixationEvent]) {
        if let eyeReceiver = currentEyeReceiver {
            // translate all fixations to page points, and insert to corresponding data in the main dictionary
            for fixEv in newData {
                // convert to screen point and flip it (smi and os x have y coordinate flipped.
                var screenPoint = NSPoint(x: fixEv.positionX, y: fixEv.positionY)
                screenPoint.y = AppSingleton.screenRect.height - screenPoint.y
                
                if let triple = eyeReceiver.screenToPage(screenPoint, fromEye: true) {
                    if currentEyeData[triple.pageIndex] != nil {
                        currentEyeData[triple.pageIndex]!.appendEvent(triple.x, y: triple.y, startTime: fixEv.startTime, endTime: fixEv.endTime, duration: fixEv.duration)
                    } else {
                        currentEyeData[triple.pageIndex] = PageEyeData(Xs: [triple.x], Ys: [triple.y], startTimes: [fixEv.startTime], endTimes: [fixEv.endTime], durations: [fixEv.duration], pageIndex: triple.pageIndex)
                    }
                }
            }
        }
    }
    
    // MARK: - External functions
    
    /// Send the given data to dime
    func sendToDiMe(dimeData: DiMeBase, endPoint: DiMeEndpoint) {
       
        if dimeAvailable {
            
            do {
                // attempt to translate json
                let options = NSJSONWritingOptions.PrettyPrinted
                try NSJSONSerialization.dataWithJSONObject(dimeData.getDict(), options: options)
                
                // assume json conversion was a success, hence send to dime
                let server_url: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerURL) as! String
                let user: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerUserName) as! String
                let password: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerPassword) as! String
                
                let credentialData = "\(user):\(password)".dataUsingEncoding(NSUTF8StringEncoding)!
                let base64Credentials = credentialData.base64EncodedStringWithOptions([])
                
                let headers = ["Authorization": "Basic \(base64Credentials)"]
                
                Alamofire.request(Alamofire.Method.POST, server_url + "/data/\(endPoint.rawValue)", parameters: dimeData.getDict(), encoding: Alamofire.ParameterEncoding.JSON, headers: headers).responseJSON {
                    _, _, response in
                    if response.isFailure {
                        AppSingleton.log.error("Error while reading json response from DiMe: \(response.debugDescription)")
                        AppSingleton.alertUser("Error while communcating with dime. Dime has now been disconnected", infoText: "Message from dime:\n\(response.debugDescription)")
                        self.dimeConnectState(false)
                    } else {
                        let json = JSON(response.value!)
                        if let error = json["error"].string {
                            AppSingleton.log.error("DiMe reply to submission contains error:\n\(error)")
                        }
                    }
                }
            } catch {
                AppSingleton.log.error("Error while deserializing json - no data sent:\n \(error)")
            }
            
        }
        
    }
    

    // MARK: - Internal functions
    
    /// Connection to dime successful / failed
    private func dimeConnectState(success: Bool) {
        if !success {
            self.dimeAvailable = false
            NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.diMeConnectionNotification, object: self, userInfo: ["available": false])
        } else {
            // succesfully connected
            self.dimeAvailable = true
            NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.diMeConnectionNotification, object: self, userInfo: ["available": true])
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
        userIsReading = true
        
        let docWindow = entryTimer.userInfo as! DocumentWindowController
        self.entryTimer = nil
        
        // retrieve status
        self.currentReadingEvent = docWindow.getCurrentStatus()
        
        // prepare to convert eye coordinates
        self.currentEyeReceiver = docWindow.pdfReader
        
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
        userIsReading = false
        self.currentEyeReceiver = nil
        
        // cancel previous entry timer, if any
        if let timer = self.entryTimer {
            dispatch_sync(timerQueue) {
                    timer.invalidate()
               }
            self.entryTimer = nil
        }
        // cancel previous exit timer, if any
        if let timer = self.exitTimer {
            dispatch_sync(timerQueue) {
                    timer.invalidate()
               }
            self.exitTimer = nil
        }
        // if there's something to send, send it
        if let currentStatus = self.currentReadingEvent {
            currentStatus.setEnd(NSDate())
            // check if there is page eye data, and append it if so
            for k in self.currentEyeData.keys {
                currentStatus.addEyeData(self.currentEyeData[k]!)
            }
            sendToDiMe(currentStatus, endPoint: .Event)
            self.currentReadingEvent = nil
            self.currentEyeData = [Int: PageEyeData]()
        }
    }
    
}

enum DiMeEndpoint: String {
    case Event = "event"
    case InformationElement = "informationelement"
}

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
    
    /// The GCD queue in which all timers are created / destroyed (to prevent potential memory leaks, they all run here)
    private let timerQueue = dispatch_queue_create("hiit.PeyeDF.HistoryManager.timerQueue", DISPATCH_QUEUE_SERIAL)
    
    /// Eye tracking events are converted / sent to dime on this queue, to avoid conflicts
    /// between exit events and fixation receipt events
    private let eyeQueue = dispatch_queue_create("hiit.PeyeDF.HistoryManager.eyeQueue", DISPATCH_QUEUE_SERIAL)
    
    /// Is true if there is a connection to DiMe, and can be used
    private(set) var dimeAvailable: Bool = false

    // MARK: - History tracking fields
    
    /// The reading event that will be sent at an exit event
    private var currentReadingEvent: ReadingEvent?
    
    /// A boolean indicating that the user is (probably) reading. Essentially, it means we are after entry timer but before exit timer (or exit event).
    private(set) var userIsReading = false
    
    /// A unix timestamp indicating when the user started reading
    private(set) var readingUnixTime = 0
    
    /// The current thing the user is probably looking at (MyPDFReader instance), which will be used to convert screen to page coordinates or retrieve eye tracking boxes.
    private var currentEyeReceiver: MyPDFReader?
    
    /// A dictionary, one entry per page (indexed by page number) containing all page eye tracking data
    private var currentEyeData = [Int: PageEyeDataChunk]()
    
    /// Markings for SMI rectangles created by incoming eye data.
    private var currentSMIMarks: PDFMarkings?
    
    /// A dictionary indicating when the user marked a paragraph in unix time
    private var manualMarkUnixtimes: [Int]
    
    /// Creates the history manager and listens for manual marks notifications
    init() {
        manualMarkUnixtimes = [Int]()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "manualParagraphMark:", name: PeyeConstants.manualParagraphMarkNotification, object: nil)
    }
    
    // MARK: - External functions
    
    /// Attempts to connect to dime. Sends a notification if we succeeded / failed
    func dimeConnect() {
        
        let server_url = AppSingleton.dimeUrl
        let headers = AppSingleton.dimeHeaders()
        
        let dictionaryObject = ["test": "test"]
        
        Alamofire.request(Alamofire.Method.POST, server_url + "/ping", parameters: dictionaryObject, encoding: Alamofire.ParameterEncoding.JSON, headers: headers).responseJSON {
            response in
            if response.result.isFailure {
                // connection failed
                AppSingleton.alertUser("Error while communcating with dime. Dime has now been disconnected", infoText: "Error message:\n\(response.result.error!)")
                
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
                
                // run only on eye serial queue, and check if user is reading
                
                dispatch_sync(eyeQueue) {

                    if self.userIsReading {
                    
                        // convert to screen point and flip it (smi and os x have y coordinate flipped.
                        var screenPoint = NSPoint(x: fixEv.positionX, y: fixEv.positionY)
                        screenPoint.y = AppSingleton.screenRect.height - screenPoint.y
                        
                        // retrieve fixation
                        if let triple = eyeReceiver.screenToPage(screenPoint, fromEye: true) {
                            if self.currentEyeData[triple.pageIndex] != nil {
                                self.currentEyeData[triple.pageIndex]!.appendEvent(triple.x, y: triple.y, startTime: fixEv.startTime, endTime: fixEv.endTime, duration: fixEv.duration, unixtime: fixEv.unixtime)
                            } else {
                                self.currentEyeData[triple.pageIndex] = PageEyeDataChunk(Xs: [triple.x], Ys: [triple.y], startTimes: [fixEv.startTime], endTimes: [fixEv.endTime], durations: [fixEv.duration], unixtimes: [fixEv.unixtime], pageIndex: triple.pageIndex, scaleFactor: eyeReceiver.getScaleFactor())
                            }
                            
                            // create rect for retrieved fixation
                            if let smiRect = eyeReceiver.getSMIRect(triple) {
                                self.currentSMIMarks?.addRect(smiRect)
                                // TODO: remove debugging check
                                if self.currentSMIMarks == nil {
                                    AppSingleton.log.debug("Nil smi marks")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - External functions
    
    /// Send the given data to dime
    /// - parameter callback: If operation was successfull, calls the given callback function using the 
    ///                       id (as Int) retrieved from DiMe
    func sendToDiMe(dimeData: DiMeBase, endPoint: DiMeEndpoint, callback: (Int -> Void)? = nil) {
       
        if dimeAvailable {
            
            do {
                // attempt to translate json
                let options = NSJSONWritingOptions.PrettyPrinted
                
                try NSJSONSerialization.dataWithJSONObject(dimeData.getDict(), options: options)
                
                // assume json conversion was a success, hence send to dime
                let server_url = AppSingleton.dimeUrl
                let headers = AppSingleton.dimeHeaders()
                
                Alamofire.request(Alamofire.Method.POST, server_url + "/data/\(endPoint.rawValue)", parameters: dimeData.getDict(), encoding: Alamofire.ParameterEncoding.JSON, headers: headers).responseJSON {
                    response in
                    if response.result.isFailure {
                        AppSingleton.log.error("Error while reading json response from DiMe: \(response.result.error)")
                        AppSingleton.alertUser("Error while communcating with dime. Dime has now been disconnected", infoText: "Message from dime:\n\(response.result.error!)")
                        self.dimeConnectState(false)
                    } else {
                        let json = JSON(response.result.value!)
                        if let error = json["error"].string {
                            AppSingleton.log.error("DiMe reply to submission contains error:\n\(error)")
                            if let message = json["message"].string {
                                AppSingleton.log.error("DiMe's error message:\n\(message)")
                            }
                        } else {
                            // assume submission was a success, call callback (if any) with returned id
                            callback?(json["id"].intValue)
                        }
                    }
                }
            } catch {
                AppSingleton.log.error("Error while serializing json - no data sent:\n\(error)")
            }
            
        }
        
    }
    
    
    /// Adds a reading rect to the current outgoing readingevent (to add manual markings)
    func addReadingRect(theRect: ReadingRect) {
        if let cre = self.currentReadingEvent {
            cre.addRect(theRect)
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
    
    // MARK: - Callbacks
    
    /// The document has been "seen" long enough, request information and prepare second (exit) timer
    @objc private func entryTimerFire(entryTimer: NSTimer) {
        readingUnixTime = NSDate().unixTime
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
                
                // prepare smi rectangles
                self.currentSMIMarks = PDFMarkings(pdfBase: docWindow.pdfReader)
        
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
        if let cre = self.currentReadingEvent {
            cre.setEnd(NSDate())
            let eventToSend = cre
            self.currentReadingEvent = nil
            
            let manualUnixTimesToSend = self.manualMarkUnixtimes
            let SMIMarksToSend = self.currentSMIMarks
            var eyeDataToSend = self.currentEyeData
            
            // run on eye serial queue
            dispatch_async(eyeQueue) {
            
                // check if there is page eye data, and append data if so
                for k in eyeDataToSend.keys {
                    // clean eye data before adding it
                    eyeDataToSend[k]!.filterData(manualUnixTimesToSend)
                    
                    eventToSend.addEyeData(eyeDataToSend[k]!)
                }
                
                // if there are smi rectangles to send, unite them and send
                if var csmi = SMIMarksToSend where csmi.getCount() > 0 {
                    csmi.flattenRectangles_eye()
                    eventToSend.extendRects(csmi.getAllReadingRects())
                }
                
                self.sendToDiMe(eventToSend, endPoint: .Event)
                
            }
            
        }
        // reset remaining properties
        self.manualMarkUnixtimes = [Int]()
        self.currentSMIMarks = nil
        self.currentEyeData = [Int: PageEyeDataChunk]()
    }
    
    /// Records that the user marked a pagraph at the given unix time
    @objc private func manualParagraphMark(notification: NSNotification) {
        let unixtime = notification.userInfo!["unixtime"]! as! Int
        manualMarkUnixtimes.append(unixtime)
    }
    
}

enum DiMeEndpoint: String {
    case Event = "event"
    case InformationElement = "informationelement"
}

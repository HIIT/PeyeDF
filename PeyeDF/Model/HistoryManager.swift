//
// Copyright (c) 2018 University of Helsinki, Aalto University
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

// The history manager is a singleton and keeps track of all history events happening through the application.
// This includes, for example, timers which trigger at predefined intervals (such as closing events after a
// specific amount of time has passed, assuming that the user went away from keyboard).
// See https://github.com/HIIT/PeyeDF/wiki/Data-Format for more information

import Foundation

/// The HistoryManager tracks all user activity, including fixations from eye tracking
class HistoryManager: FixationDataDelegate {
    
    /// Returns a shared instance of this class. This is the designed way of accessing the history manager.
    static let sharedManager = HistoryManager()
    
    /// The timer that fires when we assume that the user starts reading. Pass the DocumentWindowController as the userInfo object.
    fileprivate var entryTimer: Timer?
    
    /// The timer that fires after a certain amount of time passed, and generates an "exit event"
    fileprivate var exitTimer: Timer?
    
    /// The GCD queue in which all timers are created / destroyed (to prevent potential memory leaks, they all run here)
    fileprivate let timerQueue = DispatchQueue(label: "hiit.PeyeDF.HistoryManager.timerQueue", attributes: [])
    
    /// Eye tracking events are converted / sent to dime on this queue, to avoid conflicts
    /// between exit events and fixation receipt events
    fileprivate let eyeQueue = DispatchQueue(label: "hiit.PeyeDF.HistoryManager.eyeQueue", attributes: [])
    
    // MARK: - History tracking fields
    
    /// The reading event that will be sent at an exit event
    fileprivate var currentReadingEvent: ReadingEvent?
    
    /// A boolean indicating that the user is (probably) reading. Essentially, it means we are after entry timer but before exit timer (or exit event).
    fileprivate(set) var userIsReading = false
    
    /// A unix timestamp indicating when the user started reading
    fileprivate(set) var readingUnixTime = 0
    
    /// The current thing the user is probably looking at (PDFReader instance), which will be used to convert screen to page coordinates or retrieve eye tracking boxes.
    fileprivate weak var currentEyeReceiver: PDFReader?
    
    /// A dictionary, one entry per page (indexed by page number) containing all page eye tracking data
    fileprivate var currentEyeData = [Int: PageEyeDataChunk]()
    
    /// Markings for SMI rectangles created by incoming eye data.
    fileprivate var currentSMIMarks: PDFMarkings?
    
    /// A dictionary indicating when the user marked a paragraph in unix time
    fileprivate var manualMarkUnixtimes: [Int]
    
    /// Creates the history manager and listens for manual marks notifications
    init() {
        manualMarkUnixtimes = [Int]()
        NotificationCenter.default.addObserver(self, selector: #selector(manualParagraphMark(_:)), name: PeyeConstants.manualParagraphMarkNotification, object: nil)
    }
    
    // MARK: - External functions
    
    /// Tells the history manager that something new is happened. The history manager check if the sender is a window in front (main window) and if there is scidoc associated to it
    ///
    /// - parameter documentWindow: The window controller that is sending the message
    func entry(_ documentWindow: DocumentWindowController) {
        if let window = documentWindow.window, let _ = documentWindow.pdfReader?.sciDoc {
            if window.isMainWindow {
                // if we are tracking eyes, make sure eyes are available before starting
                if AppSingleton.eyeTracker?.available ?? false {
                    if !(AppSingleton.eyeTracker?.eyesLost ?? true) {
                        preparation(documentWindow)
                    }
                } else {
                    preparation(documentWindow)
                }
            }
        }
    }
    
    /// Tells the history manager to close the current event (we switched focus, or something similar)
    func exit(_ documentWindow: DocumentWindowController) {
        exitEvent(nil)
    }
    
    /// Adds a reading rect to the current outgoing readingevent (to add manual markings)
    func addReadingRect(_ theRect: ReadingRect) {
        if let cre = self.currentReadingEvent {
            cre.addRect(theRect)
        }
    }
    
    // MARK: - Protocol implementation
    
    func receiveNewFixationData(_ newData: [FixationEvent]) {
        
        if let eyeReceiver = currentEyeReceiver {
            
            // translate all fixations to page points, and insert to corresponding data in the main dictionary
            for fixEv in newData {
                
                // run only on eye serial queue, and check if user is reading
                
                eyeQueue.sync {

                    if self.userIsReading {
                    
                        // convert to screen point and flip it (smi and os x have y coordinate flipped.
                        var screenPoint = NSPoint(x: fixEv.positionX, y: fixEv.positionY)
                        screenPoint.y = AppSingleton.screenRect.height - screenPoint.y
                        
                        // retrieve fixation
                        if let triple = eyeReceiver.screenToPage(screenPoint, fromEye: true) {
                            if self.currentEyeData[triple.pageIndex] != nil {
                                self.currentEyeData[triple.pageIndex]!.appendEvent(triple.x, y: triple.y, startTime: fixEv.startTime, endTime: fixEv.endTime, duration: fixEv.duration, unixtime: fixEv.unixtime)
                            } else {
                                self.currentEyeData[triple.pageIndex] = PageEyeDataChunk(Xs: [triple.x], Ys: [triple.y], startTimes: [fixEv.startTime], endTimes: [fixEv.endTime], durations: [fixEv.duration], unixtimes: [fixEv.unixtime], pageIndex: triple.pageIndex, scaleFactor: Double(eyeReceiver.getScaleFactor()))
                            }
                            
                            // create rect for retrieved fixation, send to peers (if any)
                            // and store in SMIMarks
                            if let rRect = eyeReceiver.getReadingRect(triple) {
                                
                                // if we are connected to someone, sent read area to peers and add to our overview
                                if Multipeer.session.connectedPeers.count > 0,
                                  let cHash = self.currentEyeReceiver?.sciDoc?.contentHash {
                                    let area = FocusArea(forRect: rRect.rect, onPage: rRect.pageIndex as Int)
                                    CollaborationMessage.seenAreas([area]).sendToAll()
                                    Multipeer.overviewControllers[cHash]?.pdfOverview?.addArea(area, fromSource: .localPeer)
                                }
                                
                                self.currentSMIMarks?.addRect(rRect)
                            
                            } // no rect (text) was found, send a circle to peers
                              else if let zoomLevel = self.currentEyeReceiver?.scaleFactor {
                                
                                let diameter = pointSpan(zoomLevel: zoomLevel, dpi: AppSingleton.getComputedDPI()!, distancemm: AppSingleton.eyeTracker?.lastValidDistance ?? 800)
                                let circle = Circle(x: CGFloat(triple.x), y: CGFloat(triple.y), r: diameter / 4.0)
                                let area = FocusArea(forCircle: circle, onPage: triple.pageIndex)
                                
                                // send found area to peers
                                if Multipeer.session.connectedPeers.count > 0,
                                    let cHash = self.currentEyeReceiver?.sciDoc?.contentHash {
                                    CollaborationMessage.seenAreas([area]).sendToAll()
                                    Multipeer.overviewControllers[cHash]?.pdfOverview?.addArea(area, fromSource: .localPeer)
                                }
                            }
                            
                        }
                    }
                }
            }
        }

    }
    
    // MARK: - Internal functions
    
    /// Starts the "entry timer" and sets up references to the current window
    fileprivate func preparation(_ documentWindow: DocumentWindowController) {
        exitEvent(nil)
        
        guard let pdfReader = documentWindow.pdfReader, pdfReader.status == .trackable else {
            return
        }
        
        timerQueue.sync {
            self.entryTimer = Timer(timeInterval: PeyeConstants.minReadTime, target: self, selector: #selector(self.entryTimerFire(_:)), userInfo: documentWindow, repeats: false)
            DispatchQueue.main.async {
                [weak self] in
                if let timer = self?.entryTimer {
                    RunLoop.current.add(timer, forMode: RunLoopMode.commonModes)
                }
            }
        }
    }
    
    // MARK: - Callbacks
    
    /// The document has been "seen" long enough, request information and prepare second (exit) timer
    @objc fileprivate func entryTimerFire(_ entryTimer: Timer) {
        guard let docWindow = entryTimer.userInfo as? DocumentWindowController,
              let newEvent = docWindow.reportContinuedReading() else {
            return
        }
        
        readingUnixTime = Date().unixTime
        userIsReading = true
        
        self.entryTimer = nil
        
        // retrieve status
        self.currentReadingEvent = newEvent
        
        // prepare to convert eye coordinates
        self.currentEyeReceiver = docWindow.pdfReader
        
        // Multipeer: tell peers that we started reading this document
        CollaborationMessage(readingDocumentFromSciDoc: docWindow.pdfReader?.sciDoc)?.sendToAll()
        
        // prepare exit timer, which will fire when the user is inactive long enough (or will be canceled if there is another exit event).
        if let _ = self.currentReadingEvent, let pdfReader = docWindow.pdfReader {
            timerQueue.sync {
                
                // prepare smi rectangles
                self.currentSMIMarks = PDFMarkings(pdfBase: pdfReader)
        
                self.exitTimer = Timer(timeInterval: PeyeConstants.maxReadTime, target: self, selector: #selector(self.exitEvent(_:)), userInfo: nil, repeats: false)
                RunLoop.current.add(self.exitTimer!, forMode: RunLoopMode.commonModes)
            }
        }
    }
    
    /// The user has moved away, send current status (if any) and invalidate timer
    @objc fileprivate func exitEvent(_ exitTimer: Timer?) {
        userIsReading = false
        self.currentEyeReceiver = nil
        
        // cancel previous entry timer, if any
        if let timer = self.entryTimer {
            timerQueue.sync {
                timer.invalidate()
                self.entryTimer = nil
           }
        }
        // cancel previous exit timer, if any
        if let timer = self.exitTimer {
            timerQueue.sync {
                timer.invalidate()
                self.exitTimer = nil
           }
        }
        // if there's something to send, send it
        if let cre = self.currentReadingEvent {
            cre.setEnd(Date())
            let eventToSend = cre
            self.currentReadingEvent = nil
            
            let manualUnixTimesToSend = self.manualMarkUnixtimes
            let SMIMarksToSend = self.currentSMIMarks
            var eyeDataToSend = self.currentEyeData
            
            // run on eye serial queue
            eyeQueue.async {
            
                // check if there is page eye data, and append data if so
                for k in eyeDataToSend.keys {
                    // clean eye data before adding it
                    eyeDataToSend[k]!.filterData(manualUnixTimesToSend)
                    
                    eventToSend.addEyeData(eyeDataToSend[k]!)
                }
                
                // if there are smi rectangles to send, unite them and send
                if var csmi = SMIMarksToSend , csmi.getCount() > 0 {
                    csmi.flattenRectangles_eye()
                    eventToSend.extendRects(csmi.getAllReadingRects())
                }
                
                DiMePusher.sendToDiMe(eventToSend)
                
            }
            
        }
        // reset remaining properties
        self.manualMarkUnixtimes = [Int]()
        self.currentSMIMarks = nil
        self.currentEyeData = [Int: PageEyeDataChunk]()
    }
    
    /// Records that the user marked a pagraph at the given unix time
    @objc fileprivate func manualParagraphMark(_ notification: Notification) {
        let unixtime = (notification as NSNotification).userInfo!["unixtime"]! as! Int
        manualMarkUnixtimes.append(unixtime)
    }
    
}

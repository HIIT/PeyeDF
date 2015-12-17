//
//  PDF.swift
//  PeyeDF
//
//  Created by Marco Filetti on 10/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa
import Quartz

/// Implementation of a custom PDFView class, used to implement additional function related to
/// psychophysiology and user activity tracking
class MyPDFReader: MyPDFBase {
    
    /// Whether we want to annotate by clicking
    private var clickAnnotationEnabled = true
    
    /// Whether we want to draw debug circle
    lazy var drawDebugCirle: Bool = {
        return NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDrawDebugCircle) as! Bool
    }()
    
    var containsRawString = false  // this stores whether the document actually contains scanned text
    
    /// Id for this reading session, all events sent by this instance should have the same value
    let sessionId: String = { return NSUUID().UUIDString.sha1() }()
    
    /// Stores all strings searched for and found by user
    private lazy var foundStrings = { return [String]() }()
    
    /// Stores the information element for the current document.
    /// Set by DocumentWindowController.loadDocument()
    var sciDoc: ScientificDocument?
    
    /// Delegate for clicks gesture recognizer
    var clickDelegate: ClickRecognizerDelegate?
    
    // MARK: - Semi-debug fields
    
    /// Position of the circle
    var circlePosition: NSPoint?
    
    /// Size of circle
    var circleSize = NSSize(width: 20, height: 20)
    
    /// What single click does
    var singleClickMode: SingleClickMode = SingleClickMode.Default
    
    // MARK: - Event callbacks
    
    /// To receive single click actions (create "read" mark)
    override func mouseDown(theEvent: NSEvent) {
        switch singleClickMode {
        case .MarkAsRead:
            
            if theEvent.clickCount == 1 {
                // Only proceed if there is actually text to select
                if containsRawString {
                    // -- OLD STARTS HERE
    //                // Mouse in display view coordinates.
    //                var mouseDownLoc = self.convertPoint(theEvent.locationInWindow, fromView: nil)
    //                markAndAnnotate(mouseDownLoc, importance: Importance.Read)
                    // -- OLD ENDS HERE
                    
                    /// GETTING MOUSE LOCATION IN WINDOW FROM SCREEN COORDINATES
                    // get mouse in screen coordinates
                    let mouseLoc = NSEvent.mouseLocation()
                    for screen in (NSScreen.screens() as [NSScreen]!) {
                        if NSMouseInRect(mouseLoc, screen.frame, false) {
                            let tinySize = NSSize(width: 1, height: 1)
                            let mouseRect = NSRect(origin: mouseLoc, size: tinySize)
                            //let rawLocation = screen.convertRectToBacking(mouseRect)
                            
                            // use raw location to map back into view coordinates
                            let mouseInWindow = self.window!.convertRectFromScreen(mouseRect)
                            let mouseInView = self.convertRect(mouseInWindow, fromView: self.window!.contentViewController!.view)
                            markAndAnnotate(mouseInView.origin, importance: ReadingClass.Read)
                        }
                    }
                } else {
                    super.mouseDown(theEvent)
                }
            }
            
        case .MoveCrosshair:
            /// GETTING MOUSE LOCATION IN WINDOW FROM SCREEN COORDINATES
            // get mouse in screen coordinates
            let mouseLoc = NSEvent.mouseLocation()
            for screen in NSScreen.screens() as [NSScreen]! {
                if NSMouseInRect(mouseLoc, screen.frame, false) {
                    let tinySize = NSSize(width: 1, height: 1)
                    let mouseRect = NSRect(origin: mouseLoc, size: tinySize)
                    let mouseInWindow = self.window!.convertRectFromScreen(mouseRect)
                    let mouseInView = self.convertRect(mouseInWindow, fromView: self.window!.contentViewController!.view)
                    
                    if let oldPosition = circlePosition {
                        let oldPageRect = NSRect(origin: oldPosition, size: circleSize)
                        let screenRect = convertRect(oldPageRect, fromPage: currentPage())
                        setNeedsDisplayInRect(screenRect.addTo(scaleFactor()))
                    }
                    
                    circlePosition = convertPoint(mouseInView.origin, toPage: currentPage())
                    var screenRect = NSRect(origin: circlePosition!, size: circleSize)
                    screenRect = convertRect(screenRect, fromPage: currentPage())
                    setNeedsDisplayInRect(screenRect.addTo(scaleFactor()))

                }
            }
            
        case .Default:
            super.mouseDown(theEvent)
            
        }
    }
    
    // MARK: - Received actions
    
    /// Looks up a found selection, used when a user selects a search result
    func foundResult(selectedResult: PDFSelection) {
        setCurrentSelection(selectedResult, animate: false)
        scrollSelectionToVisible(self)
        setCurrentSelection(selectedResult, animate: true)
        let foundString = selectedResult.string().lowercaseString
        if foundStrings.indexOf(foundString) == nil {
            foundStrings.append(foundString)
        }
        let foundOnPage = selectedResult.pages()[0] as! PDFPage
        let pageIndex = document().indexForPage(foundOnPage)
        let newRect = ReadingRect(pageIndex: pageIndex, rect: selectedResult.boundsForPage(foundOnPage), readingClass: .FoundString, classSource: .Search, pdfBase: self)
        markings.addRect(newRect)
        HistoryManager.sharedManager.addReadingRect(newRect)
    }
    
    // MARK: - Page drawing override
    
    /// To draw extra stuff on page
    override func drawPage(page: PDFPage!) {
    	// Let PDFView do most of the hard work.
        super.drawPage(page)
       
        if drawDebugCirle {
        	// Save.
            NSGraphicsContext.saveGraphicsState()
    	
            // Draw.
            if let circlePosition = circlePosition {
                // Draw what you need
                let circleRect = NSRect(origin: circlePosition, size: circleSize)
        	
                let borderColor = NSColor(red: 0.9, green: 0.0, blue: 0.0, alpha: 0.8)
                borderColor.set()
                
                let circlePath: NSBezierPath = NSBezierPath(ovalInRect: circleRect)
                circlePath.lineWidth = 3.0
                circlePath.stroke()
            }
            
        	// Restore.
        	NSGraphicsContext.restoreGraphicsState()
        }
    }
    
    
    // MARK: - Markings and Annotations
    
    /// This method is called (so far) only by the undo manager. It sets the state of markings to the specified object (markingState) and
    /// refreshes the view on the marking corresponding to the last rectangle's property of the given marking state (so that the last
    /// added / removed rectangle can be seen appearing / disappearing immediately).
    @objc func undoMarkAndAnnotate(previousState: PDFMarkingsState) {
        // a last tuple must be present, otherwise it should not have been added in the first place
        if let lastRect = previousState.getLastRect() {
            
            // store previous state before making any modification
            let evenPreviousState = PDFMarkingsState(oldState: markings.getAll(forSource: .Click))
            
            // apply previous state and perform annotations
            markings.setAll(forSource: .Click, newRects: previousState.rectState)
            autoAnnotate()
        
            // show this change
            let annotRect = annotationRectForMark(lastRect.rect)
            setNeedsDisplayInRect(convertRect(annotRect, fromPage: self.document().pageAtIndex(lastRect.pageIndex.integerValue)))
            
            // create an undo operation for this operation
            let lastR = previousState.getLastRect()!
            evenPreviousState.setLastRect(lastR)
            undoManager?.registerUndoWithTarget(self, selector: "undoMarkAndAnnotate:", object: evenPreviousState)
            undoManager?.setActionName(NSLocalizedString("actions.annotate", value: "Mark Text", comment: "Some text was marked as importance by clicking"))
        } else {
            let exception = NSException(name: "This should never happen!", reason: "Undoing a nil last rectangle", userInfo: nil)
            exception.raise()
        }
    }
    
    /// Create a marking (and subsequently a rect) at the given point, and make annotations.
    /// Sends a notification that a marking was done.
    ///
    /// - parameter location: The point for which a rect will be created (in view coordinates)
    /// - parameter importance: The importance of the rect that will be created
    func markAndAnnotate(location: NSPoint, importance: ReadingClass) {
        if containsRawString {
            // prepare a marking state to store this operation
            let previousState = PDFMarkingsState(oldState: self.markings.getAll(forSource: .Click))
            let newMaybeMark = mark(location, importance: importance)
            // if noting was done (i.e. no paragraph at point) do nothing, otherwise store state and annotate
            if let newMark = newMaybeMark {
                previousState.setLastRect(newMark)
                undoManager?.registerUndoWithTarget(self, selector: "undoMarkAndAnnotate:", object: previousState)
                undoManager?.setActionName(NSLocalizedString("actions.annotate", value: "Mark Text", comment: "Some text was marked as importance by clicking"))
                autoAnnotate()
            }
        }
        let unixtimeDict = ["unixtime": NSDate().unixTime]
        NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.manualParagraphMarkNotification, object: self, userInfo: unixtimeDict)
    }
    
    /// Manually tell that a point (and hence the paragraph/subparagraph related to it
    /// should be marked as somehow important
    ///
    /// - returns: A triplet containing the rectangle that was created, on which page it was created and what importance
    func mark(locationInView: NSPoint, importance: ReadingClass) -> ReadingRect? {
        
        // Page we're on.
        let activePage = self.pageForPoint(locationInView, nearest: true)
        
        // Index for current page
        let pageIndex = self.document().indexForPage(activePage)
        
        // Get location in "page space".
        let pagePoint = self.convertPoint(locationInView, toPage: activePage)
        
        // Convert point to rect, if possible
        guard let markRect = pointToParagraphRect(pagePoint, forPage: activePage) else {
            return nil
        }
        
        if importance != ReadingClass.Read && importance != ReadingClass.Interesting && importance != ReadingClass.Critical {
            let exception = NSException(name: "Not implemented", reason: "Unsupported reading class for annotation", userInfo: nil)
            exception.raise()
        }
        
        // Create new reading rect using given parameters and put in history for dime submission
        let newRect = ReadingRect(pageIndex: pageIndex, rect: markRect, readingClass: importance, classSource: .Click, pdfBase: self)
        markings.addRect(newRect)
        HistoryManager.sharedManager.addReadingRect(newRect)
        
        return newRect
    }
    
    /// Returns wheter annotation by click is enabled
    func clickAnnotationIsEnabled() -> Bool {
        return self.clickAnnotationEnabled
    }
    
    /// Enabled / disables auto annotation by click
    func setClickAnnotationTo(enabled: Bool) {
        self.clickAnnotationEnabled = enabled
        self.clickDelegate?.setRecognizersTo(enabled)
    }
    
    // MARK: - General accessor methods
    
    /// Converts a point on screen and returns a triple containing x coordinate, y coordinate (both in page space) and page index. Should be called for each fixation retrieved during the current event.
    ///
    /// - parameter pointOnScreen: point to convert (in OS X coordinate system)
    /// - parameter fromEye: if this is being done because of eye tracking (so gaze points are stored)
    /// - returns: A triple containing x, y in page coordinates, and the index of the page in which gaze fell
    func screenToPage(pointOnScreen: NSPoint, fromEye: Bool) -> (x: CGFloat, y: CGFloat, pageIndex: Int)? {
        let tinySize = NSSize(width: 1, height: 1)
        let tinyRect = NSRect(origin: pointOnScreen, size: tinySize)
        
        let rectInWindow = self.window!.convertRectFromScreen(tinyRect)
        let rectInView = self.convertRect(rectInWindow, fromView: self.window!.contentViewController!.view)
        let pointInView = rectInView.origin
        
        //  return nil if the point is outside this view
        if pointInView.x < 0 || pointInView.y < 0 || pointInView.x > frame.width || pointInView.y > frame.height {
            return nil
        }
        // otherwise calculate point on page, but return nil if point is out of page
        let page = pageForPoint(pointInView, nearest:false)
        if page == nil {
            return nil
        }
        let pointOnPage = self.convertPoint(pointInView, toPage: page)
        
        // start debug- circle
        if drawDebugCirle {
            for visiblePage in visiblePages() as! [PDFPage] {
                if let oldPosition = circlePosition {
                    let oldPageRect = NSRect(origin: oldPosition, size: circleSize)
                    let screenRect = convertRect(oldPageRect, fromPage: visiblePage)
                    setNeedsDisplayInRect(screenRect.addTo(scaleFactor()))
                }
                
                circlePosition = pointOnPage
                var screenRect = NSRect(origin: circlePosition!, size: circleSize)
                screenRect = convertRect(screenRect, fromPage: visiblePage)
                setNeedsDisplayInRect(screenRect.addTo(scaleFactor()))
            }
        }
        // End debug - circle
        
        // create rect for gazed-at paragraph. Note: this will store rects that will later be sent
        // in a summary event. This is different from eye rectangles created by each fixation and
        // sent in the current (non-summary) reading event, as done by HistoryManager calling getSMIRect
        // (preferred method in PeyeDF 0.4+).
        // TODO: to be deleted
        if fromEye {
            if let seenRect = pointToParagraphRect(pointOnPage, forPage: page) {
                let newRect = ReadingRect(pageIndex: self.document().indexForPage(page), rect: seenRect, readingClass: .Paragraph, classSource: .SMI, pdfBase: self)
                markings.addRect(newRect)
                HistoryManager.sharedManager.addReadingRect(newRect)
            }
        }
        
        let pageIndex = self.document().indexForPage(page)
        return (x: pointOnPage.x, y: pointOnPage.y, pageIndex: pageIndex)
    }
    
    /// Creates a SMI rect using the triple returned from screenToPage, corresponding to the paragraph contained within 3 degrees of visual angle of the given fixation. As of PeyeDF 0.4+, this is the preferred method to send SMI paragraphs to dime.
    func getSMIRect(triple: (x: CGFloat, y: CGFloat, pageIndex: Int)) -> ReadingRect? {
        let pointOnPage = NSPoint(x: triple.x, y: triple.y)
        let pdfPage = document().pageAtIndex(triple.pageIndex)
        if let sr = pointToParagraphRect(pointOnPage, forPage: pdfPage) {
            return ReadingRect(pageIndex: triple.pageIndex, rect: sr, readingClass: .Paragraph, classSource: .SMI, pdfBase: self)
        } else {
            return nil
        }
    }
    
    /// Gets the current scaleFactor (zoom level)
    func getScaleFactor() -> CGFloat {
        return scaleFactor()
    }
    
    /// Converts the current viewport to a reading event.
    ///
    /// - returns: The reading event for the current status, or nil if nothing is actually visible
    func getViewportStatus() -> ReadingEvent? {
        if self.visiblePages() != nil {
            let visiblePageLabels: [String] = getVisiblePageLabels()
            let visiblePageNums: [Int] = getVisiblePageNums()
            let pageRects: [NSRect] = getVisibleRects()
            var plainTextContent: NSString = ""
            
            if let textContent = getVisibleString() {
                plainTextContent = textContent
            }
            
            var readingRects = [ReadingRect]()
            var vpi = 0
            for rect in pageRects {
                let visiblePageNum = visiblePageNums[vpi]
                let newRect = ReadingRect(pageIndex: visiblePageNum, rect: rect, readingClass: ReadingClass.Viewport, classSource: ClassSource.Viewport, pdfBase: self)
                readingRects.append(newRect)
                vpi++
            }
            
            return ReadingEvent(sessionId: sessionId, pageNumbers: visiblePageNums, pageLabels: visiblePageLabels, pageRects: readingRects, plainTextContent: plainTextContent, infoElemId: sciDoc!.getId())
        } else {
            return nil
        }
    }
    
    /// Returns all rectangles with their corresponding class, marked by the user (and basic eye tracking)
    ///
    /// - returns: A summary reading event corresponding to all marks, nil if proportion read / interesting
    ///            etc was less than a minimum amount (suggesting the document wasn't actually read)
    func getUserRectStatus() -> SummaryReadingEvent? {
        markings.flattenRectangles_eye()
        
        // Calculate proportion for Read, Critical and Interesting rectangles
        let proportionTriple = calculateProportions_manual()
        
        var totProportion = 0.0
        totProportion += proportionTriple.proportionRead
        totProportion += proportionTriple.proportionInteresting
        totProportion += proportionTriple.proportionCritical
        
        let proportionGazed = calculateProportion_smi()
        
        if totProportion < PeyeConstants.minProportion && proportionGazed < PeyeConstants.minProportion {
            return nil
        } else {
            return SummaryReadingEvent(rects: markings.getAllReadingRects(), sessionId: sessionId, plainTextContent: nil, infoElemId: sciDoc!.getId(), foundStrings: foundStrings, pdfReader: self, proportionTriple: proportionTriple)
        }
    }
    
    /// Get the rectangle of the pdf view, in screen coordinates
    func getRectOfViewOnScreen() -> NSRect {
        // get a rectangle representing the pdfview frame, relative to its superview and convert to the window's view
        let r1:NSRect = self.superview!.convertRect(self.frame, toView: self.window!.contentView!)
        // get screen coordinates corresponding to the rectangle got in the previous line
        let r2 = self.window!.convertRectToScreen(r1)
        return r2
    }
    
    /// Check if page labels and page numbers are the same for the current document
    func pageNumbersSameAsLabels() -> Bool {
        for i in 0..<document().pageCount() {
            let page = document().pageAtIndex(i)
            if page.label() != "\(i+1)" {
                return false
            }
        }
        return true
    }
    
    /// Returns the visible text as a string, or nil if no text can be fetched.
    func getVisibleString() -> NSString? {
        // Only proceed if there is actually text to select
        if containsRawString {
            let visiblePages = self.visiblePages()
            let generatedSelection = PDFSelection(document: self.document())
            
            for visiblePage in visiblePages as! [PDFPage] {
                
                // Get page's rectangle coordinates
                let pageRect = getPageRect(visiblePage)
                
                // Get viewport rect and apply margin
                var visibleRect = NSRect(origin: CGPoint(x: 0, y: 0), size: self.frame.size)
                visibleRect.insetInPlace(dx: PeyeConstants.extraMargin, dy: PeyeConstants.extraMargin)
                
                visibleRect = self.convertRect(visibleRect, toPage: visiblePage)  // Convert rect to page coordinates
                visibleRect.intersectInPlace(pageRect)  // Intersect to get seen portion
                
                generatedSelection.addSelection(visiblePage.selectionForRect(visibleRect))
            }
            
            return generatedSelection.string()
        }
        return nil
    }
   
    // MARK: - Debug functions
    
    /// Debug function to test "seen text"
    func selectVisibleText(sender: AnyObject?) {
        // Only proceed if there is actually text to select
        if containsRawString {
            let visiblePages = self.visiblePages()
            let generatedSelection = PDFSelection(document: self.document())
            
            for visiblePage in visiblePages as! [PDFPage] {
                
                // Get page's rectangle coordinates
                let pageRect = getPageRect(visiblePage)
                
                // Get viewport rect and apply margin
                var visibleRect = NSRect(origin: CGPoint(x: 0, y: 0), size: self.frame.size)
                visibleRect.insetInPlace(dx: PeyeConstants.extraMargin, dy: PeyeConstants.extraMargin)
                
                visibleRect = self.convertRect(visibleRect, toPage: visiblePage)  // Convert rect to page coordinates
                visibleRect.intersectInPlace(pageRect)  // Intersect to get seen portion
                
                generatedSelection.addSelection(visiblePage.selectionForRect(visibleRect))
            }
            
            self.setCurrentSelection(generatedSelection, animate: true)
        }
    }
    
}

/// Semi-debug enum
enum SingleClickMode {
    case Default
    case MarkAsRead
    case MoveCrosshair
}
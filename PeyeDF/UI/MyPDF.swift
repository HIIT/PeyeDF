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

// Constants
let extraLineAmount = 3 // 1/this number is the amount of extra lines that we want to discard
                        // if we are at beginning or end of paragraph

/// Used to convert points on screen to points on a page
protocol ScreenToPageConverter: class {
    
    /// Converts a point on screen and returns a tuple containing x coordinate, y coordinate, BOTH on page points
    ///
    /// - parameter pointOnScreen: point to convert (in OS X coordinate system)
    /// - parameter fromEye: if this is being done because of eye tracking (so gaze points are stored)
    /// - returns: A triple containing x, y in page coordinates, and the index of the page in which gaze fell
    func screenToPage(pointOnScreen: NSPoint, fromEye: Bool) -> (x: CGFloat, y: CGFloat, pageIndex: Int)?
    
}

/// Implementation of a custom PDFView class, used to implement additional function related to
/// psychophysiology and user activity tracking
class MyPDF: PDFView, ScreenToPageConverter {
    
    /// Whether we want to annotate by clicking
    private var clickAnnotationEnabled = true
    
    var containsRawString = false  // this stores whether the document actually contains scanned text
    
    /// Stores the information element for the current document.
    /// Set by DocumentWindowController.loadDocument()
    var sciDoc: ScientificDocument?
    
    /// Stores all rects at which the user looked at (via screenToPage(_, true))
    var gazedRects = [PDFPage: [NSRect]]()

    /// Stores all manually entered markings
    var manualMarks = PDFMarkings(withSource: ClassSource.Click)
    
    /// Delegate for clicks gesture recognizer
    var clickDelegate: ClickRecognizerDelegate?
    
    // MARK: - Semi-debug fields
    
    /// Position of the circle
    var circlePosition: NSPoint?
    
    /// Size of circle
    var circleSize = NSSize(width: 20, height: 20)
    
    /// What single click does
    var singleClickMode: SingleClickMode = SingleClickMode.MarkAsRead
    
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
                        setNeedsDisplayInRect(screenRect.scale(scaleFactor()))
                    }
                    
                    circlePosition = convertPoint(mouseInView.origin, toPage: currentPage())
                    var screenRect = NSRect(origin: circlePosition!, size: circleSize)
                    screenRect = convertRect(screenRect, fromPage: currentPage())
                    setNeedsDisplayInRect(screenRect.scale(scaleFactor()))

                }
            }
            
        case .Default:
            super.mouseDown(theEvent)
            
        }
    }
    
    // MARK: - Page drawing override
    
    /// To draw extra stuff on page
    override func drawPage(page: PDFPage!) {
    	// Let PDFView do most of the hard work.
        super.drawPage(page)
        
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
    
    // MARK: - Internal functions
    
    /// Converts a point to a rectangle corresponding to the paragraph in which the point resides.
    ///
    /// - parameter pagePoint: the point of interest
    /// - parameter forPage: the page of interest
    /// - returns: A rectangle corresponding to the point, nil if there is no paragraph
    private func pointToParagraphRect(pagePoint: NSPoint, forPage activePage: PDFPage) -> NSRect? {
        let pointArray = verticalFocalPoints(fromPoint: pagePoint, zoomLevel: self.scaleFactor(), pageRect: self.getPageRect(activePage))
        
        // if using columns, selection can "bleed" into footers and headers
        // solution: check the median height and median width of each selection, and discard
        // everything which is lineAutoSelectionTolerance bigger than that
        var selections = [PDFSelection]()
        for point in pointArray {
            selections.append(activePage.selectionForLineAtPoint(point))
        }
        
        if selections.count == 0 {
            return nil
        }
        
        let medI = selections.count / 2  // median point for selection array
        
        // sort selections by height (disabled, using middle point instead)
        // selections.sort({$0.boundsForPage(activePage).height > $1.boundsForPage(activePage).height})
        let medianHeight = selections[medI].boundsForPage(activePage).height
        
        // sort selections by width (disabled, using median point)
        // selections.sort({$0.boundsForPage(activePage).width > $1.boundsForPage(activePage).width})
        let medianWidth = selections[medI].boundsForPage(activePage).width
        
        let isHorizontalLine = medianHeight < medianWidth
        
        // If the line is vertical, skip
        if !isHorizontalLine {
            return nil
        }
        
        let medianSize = NSSize(width: medianWidth, height: medianHeight)
        
        // reject selections which are too big
        let filteredSelections = selections.filter({$0.boundsForPage(activePage).size.withinMaxTolerance(medianSize, tolerance: PeyeConstants.lineAutoSelectionTolerance)})
        
        var pdfSel = PDFSelection(document: self.document())
        for selection in filteredSelections {
            pdfSel.addSelection(selection)
        }
        
        // if top / bottom third of the lines comprise a part of another paragraph, leave them out
        // detect this by using new lines
        
        // get selection line by line
        if let selLines = pdfSel.selectionsByLine() {
            let nOfExtraLines: Int = Int(floor(CGFloat(selLines.count) / CGFloat(extraLineAmount)))
            
            // split selection into beginning / end separating by new line
            
            // only proceed if there are extra lines
            if nOfExtraLines > 0 {
                var lineStartIndex = 0
                // check if part before new line is included in any of the extra beginning lines,
                // if so skip them
                for i in 0..<nOfExtraLines {
                    let currentLineSel = selLines[i] as! PDFSelection
                    let cLString = currentLineSel.string() + "\r"
                    if let _ = activePage.string().rangeOfString(cLString) {
                        lineStartIndex = i+1
                        break
                    }
                }
                
                // do the same for the ending part
                var lineEndIndex = selLines.count-1
                for i in Array((selLines.count-1-nOfExtraLines..<selLines.count).reverse()) {
                    let currentLineSel = selLines[i] as! PDFSelection
                    let cLString = currentLineSel.string() + "\r"
                    if let _ = activePage.string().rangeOfString(cLString) {
                        lineEndIndex = i
                        break
                    }
                }
                
                // generate new selection not taking into account excluded parts
                pdfSel = PDFSelection(document: self.document())
                for i in lineStartIndex...lineEndIndex {
                    pdfSel.addSelection(selLines[i] as! PDFSelection)
                }
                
            } // end of check for split, if no need just return selection as-was //
        } else {
            return nil
        }
        
        // The new rectangle for this point
        return pdfSel.boundsForPage(activePage)
    }
    
    // MARK: - Markings and Annotations
    
    /// Manually set all rectangles to the given parameters, and annotate them.
    func setMarksAndAnnotate(newManualMarks: PDFMarkings) {
        self.manualMarks = newManualMarks
        autoAnnotate()
    }
    
    /// This method is called (so far) only by the undo manager. It sets the state of markings to the specified object (markingState) and
    /// refreshes the view on the marking corresponding to the last rectangle's property of the given marking state (so that the last
    /// added / removed rectangle can be seen appearing / disappearing immediately).
    @objc func undoMarkAndAnnotate(previousState: PDFMarkingsState) {
        // a last tuple must be present, otherwise it should not have been added in the first place
        if let lastTuple = previousState.getLastRect() {
            
            // store previous state before making any modification
            let evenPreviousState = PDFMarkingsState(oldState: manualMarks)
            
            // apply previous state and perform annotations
            manualMarks = previousState.rectState
            autoAnnotate()
        
            // show this change
            let annotRect = annotationRectForMark(lastTuple.lastRect, page: lastTuple.lastPage)
            setNeedsDisplayInRect(convertRect(annotRect, fromPage: lastTuple.lastPage))
            
            // create an undo operation for this operation
            let lastR = previousState.getLastRect()!
            evenPreviousState.setLastRect(lastR.lastRect, lastPage: lastR.lastPage)
            undoManager?.registerUndoWithTarget(self, selector: "undoMarkAndAnnotate:", object: evenPreviousState)
            undoManager?.setActionName(NSLocalizedString("actions.annotate", value: "Mark Text", comment: "Some text was marked as importance by clicking"))
        } else {
            let exception = NSException(name: "This should never happen!", reason: "Undoing a nil last rectangle", userInfo: nil)
            exception.raise()
        }
    }
    
    /// Create a marking (and subsequently a rect) at the given point, and make annotations
    ///
    /// - parameter location: The point for which a rect will be created (in view coordinates)
    /// - parameter importance: The importance of the rect that will be created
    func markAndAnnotate(location: NSPoint, importance: ReadingClass) {
        if containsRawString {
            // prepare a marking state to store this operation
            let previousState = PDFMarkingsState(oldState: self.manualMarks)
            let newTuple = mark(location, importance: importance)
            // if noting was done (i.e. no paragraph at point) do nothing, otherwise store state and annotate
            if let newMark = newTuple {
                previousState.setLastRect(newMark.newRect, lastPage: newMark.onPage)
                undoManager?.registerUndoWithTarget(self, selector: "undoMarkAndAnnotate:", object: previousState)
                undoManager?.setActionName(NSLocalizedString("actions.annotate", value: "Mark Text", comment: "Some text was marked as importance by clicking"))
                autoAnnotate()
            }
        }
    }
    
    /// Manually tell that a point (and hence the paragraph/subparagraph related to it
    /// should be marked as somehow important
    ///
    /// - returns: A triplet containing the rectangle that was created, on which page it was created and what importance
    func mark(locationInView: NSPoint, importance: ReadingClass) -> (newRect: NSRect, onPage: PDFPage, importance: ReadingClass)? {
        
        // Page we're on.
        let activePage = self.pageForPoint(locationInView, nearest: true)
        
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
        
        manualMarks.addRect(markRect, ofClass: importance, forPage: activePage)
        
        return (markRect, activePage, importance)
    }
    
    /// Remove all annotations which are a line and match the annotations colours
    /// defined in PeyeConstants
    func removeAllAnnotations() {
        for i in 0..<document()!.pageCount() {
            let page = document()!.pageAtIndex(i)
            for annColour in PeyeConstants.annotationAllColours {
                for annotation in page.annotations() {
                    if let annotation = annotation as? PDFAnnotationSquare {
                        if annotation.color().practicallyEqual(annColour) {
                            page.removeAnnotation(annotation)
                        }
                    }
                }
            }
        }
    }
    
    /// Create PDFAnnotationLines related to the markings of the specified class
    ///
    /// - parameter forClass: The class of annotations to output
    /// - parameter colour: The color to use, generally defined in PeyeConstants
    func outputAnnotations(forClass: ReadingClass, colour: NSColor) {
        let lineThickness: CGFloat = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefAnnotationLineThickness) as! CGFloat
        let myBord = PDFBorder()
        myBord.setLineWidth(lineThickness)
        
        for page in manualMarks.get(forClass).keys {
            for rect in manualMarks.get(forClass)[page]! {
                let newRect = annotationRectForMark(rect, page: page)
                let annotation = PDFAnnotationSquare(bounds: newRect)
                annotation.setColor(colour)
                annotation.setBorder(myBord)
                
                page.addAnnotation(annotation)
                
                // tell the view to immediately refresh itself in an area which includes the
                // line's "border"
                setNeedsDisplayInRect(convertRect(newRect, fromPage: page))
            }
        }
    }
    
    /// Writes all annotations corresponding to all marks, and deletes intersecting rectangles for "lower-class" rectangles which
    /// intersect with "higher-class" rectangles
    func autoAnnotate() {
        removeAllAnnotations()
        manualMarks.flattenRectangles_relevance()
        outputAnnotations(.Critical, colour: PeyeConstants.annotationColourCritical)
        outputAnnotations(.Interesting, colour: PeyeConstants.annotationColourInteresting)
        outputAnnotations(.Read, colour: PeyeConstants.annotationColourRead)
        
        // Placeholder for a better way to enable this
        NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "autoAnnotateCallback", userInfo: nil, repeats: false)
    }
    
    @objc func autoAnnotateCallback() {
        NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.autoAnnotationComplete, object: self)
    }
    
    /// Returns a rectangle corresponding to the annotation for a rectangle corresponding to the mark, using all appropriate constants / preferences.
    ///
    /// - parameter markRect: The rectangle corresponding to the mark
    /// - parameter page: The page on which the mark resides, and on which the annotation will be created
    /// - returns: A rectangle representing the annotation
    func annotationRectForMark(markRect: NSRect, page: PDFPage) -> NSRect {
        let lineThickness = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefAnnotationLineThickness) as! CGFloat
        let newRect_x = markRect.origin.x - PeyeConstants.annotationLineDistance
        let newRect_y = markRect.origin.y
        let newRect_height = markRect.height
        let newRect_width: CGFloat = lineThickness
        return NSRect(x: newRect_x, y: newRect_y, width: newRect_width, height: newRect_height)
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
    
    // MARK: - Protocol implementations
    
    /// Converts a point on screen and returns a tuple containing x coordinate, y coordinate, BOTH on page points
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
        
        // TODO: remove debug-circle
        // start debug- circle
        
        if let oldPosition = circlePosition {
            let oldPageRect = NSRect(origin: oldPosition, size: circleSize)
            let screenRect = convertRect(oldPageRect, fromPage: currentPage())
            setNeedsDisplayInRect(screenRect.scale(scaleFactor()))
        }
        
        circlePosition = pointOnPage
        var screenRect = NSRect(origin: circlePosition!, size: circleSize)
        screenRect = convertRect(screenRect, fromPage: currentPage())
        setNeedsDisplayInRect(screenRect.scale(scaleFactor()))
        // End debug - circle
        
        // create rect for gazed-at paragraph
        if fromEye {
            if let seenRect = pointToParagraphRect(pointOnPage, forPage: page) {
                if gazedRects[page] == nil {
                    gazedRects[page] = [NSRect]()
                }
                gazedRects[page]!.append(seenRect)
            }
        }
        
        let pageIndex = self.document().indexForPage(page)
        return (x: pointOnPage.x, y: pointOnPage.y, pageIndex: pageIndex)
    }
    
    // MARK: - General accessor methods
    
    /// Converts the current viewport to a reading event.
    ///
    /// - returns: The reading event for the current status, or nil if nothing is actually visible
    func getViewportStatus() -> ReadingEvent? {
        if self.visiblePages() != nil {
            let multiPage: Bool = (self.visiblePages().count) > 1
            let visiblePageLabels: [String] = getVisiblePageLabels()
            let visiblePageNums: [Int] = getVisiblePageNums()
            let pageRects: [NSRect] = getVisibleRects()
            var plainTextContent: NSString = ""
            
            if let textContent = getVisibleString() {
                plainTextContent = textContent
            }
            
            // TODO: remove this debugging check
            if visiblePageNums.count != pageRects.count {
                fatalError("Number of visible pages and visible rectangles does not match")
            }
            
            var readingRects = [ReadingRect]()
            var vpi = 0
            for rect in pageRects {
                let visiblePageNum = visiblePageNums[vpi]
                let newRect = ReadingRect(pageIndex: visiblePageNum, rect: rect, readingClass: ReadingClass.Viewport, classSource: ClassSource.Viewport)
                readingRects.append(newRect)
                vpi++
            }
            
            return ReadingEvent(multiPage: multiPage, pageNumbers: visiblePageNums, pageLabels: visiblePageLabels, pageRects: readingRects, isSummary: false, scaleFactor: self.scaleFactor(), plainTextContent: plainTextContent, infoElemId: sciDoc!.getId())
        } else {
            return nil
        }
    }
    
    /// Returns all rectangles with their corresponding class, marked by the user (and basic eye tracking)
    func getUserRectStatus() -> ReadingEvent {
        fatalError("not implemented")
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
    
    /// Get media box for page, representing coordinates which take into account if
    /// page has been cropped (in Preview, for example). By default returns
    /// media box instead if crop box is not present, which is what we want
    func getPageRect(page: PDFPage) -> NSRect {
        return page.boundsForBox(kPDFDisplayBoxCropBox)
    }
   
    /// Get proportion of document currently being seen, as a pair of numbers from
    /// 0 to 1 (e.g. 0, 0.25 means that we are observing the first quarter of a document, or whole page 1 out of 4).
    /// Note: this is biased in excess (for example if we are seeing two pages side-by-side it returns the smallest min and the highest max possible).
    @available(*, unavailable, message="Proportions are no longer used, everything should be done using rects.")
    func getProportion() -> DiMeRange {
        let clipView = self.subviews[0].subviews[0] as! NSClipView  // forced assumption on the clipview tree
        let yMin = clipView.visibleRect.origin.y
        let yMax = yMin + clipView.visibleRect.height
        let docY = clipView.documentRect.height
        return DiMeRange(min: 1 - yMax / docY, max: 1 - yMin / docY)
    }
    
    /// Get the number of visible page numbers (starting from 0)
    func getVisiblePageNums() -> [Int] {
        var visibleArray = [Int]()
        for visiblePage in self.visiblePages() as! [PDFPage] {
            visibleArray.append(document().indexForPage(visiblePage))
        }
        return visibleArray
    }
    
    /// Get the number of visible page labels (as embedded in the PDF)
    func getVisiblePageLabels() -> [String] {
        var visibleArray = [String]()
        for visiblePage in self.visiblePages() as! [PDFPage] {
            visibleArray.append(visiblePage.label())
        }
        return visibleArray
    }
    
    /// Returns the list of rects corresponding to portion of pages being seen
    func getVisibleRects() -> [NSRect] {
        let visiblePages = self.visiblePages()
        var visibleRects = [NSRect]()  // rects in page coordinates, one for each page, representing visible portion
        
        for visiblePage in visiblePages as! [PDFPage] {
            
            // Get page's rectangle coordinates
            let pageRect = getPageRect(visiblePage)
            
            // Get viewport rect and apply margin
            var visibleRect = NSRect(origin: CGPoint(x: 0, y: 0), size: self.frame.size)
            visibleRect.insetInPlace(dx: PeyeConstants.extraMargin, dy: PeyeConstants.extraMargin)
            
            visibleRect = self.convertRect(visibleRect, toPage: visiblePage)  // Convert rect to page coordinates
            visibleRect.intersectInPlace(pageRect)  // Intersect to get seen portion
            visibleRects.append(visibleRect)
            
        }
        return visibleRects
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
    
    // MARK: - No longer used
    
    // ROTATING ANNOTATION LINES FOR VERTICAL TEXT LINES
    //        } else {
    //            let newRect_y = rect.origin.y + rect.height + PeyeConstants.annotationLineDistance
    //            let newRect_x = rect.origin.x
    //            let newRect_width = rect.width
    //            let newRect_height: CGFloat = 1.0
    //            newRect = NSRect(x: newRect_x, y: newRect_y, width: newRect_width, height: newRect_height)
    //        }
    
}

/// Semi-debug enum
enum SingleClickMode {
    case Default
    case MarkAsRead
    case MoveCrosshair
}
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

/// How important is a paragraph
public enum Importance {
    case Read
    case Important
    case Critical
}

/// This class represents a "marking state", that is a selection of importance rectangles and the last rectangle and
/// last page that were edited. It is used to store states in undo operations.
class MarkingState: NSObject {
    /// Rectangles of "critical" marks, prior to addition / deletion
    var criticalRects: [PDFPage: [NSRect]]
    /// Rectangles of "interesting" marks, prior to addition / deletion
    var interestingRects: [PDFPage: [NSRect]]
    /// Rectangles of "read" marks, prior to addition / deletion
    var readRects: [PDFPage: [NSRect]]
    /// The page on which the last modification was made
    private var lastPage: PDFPage?
    /// The rectangle on which the last modification was made
    private var lastRect: NSRect?
    
    init(criticalRects: [PDFPage: [NSRect]], interestingRects: [PDFPage: [NSRect]], readRects: [PDFPage: [NSRect]]) {
        self.criticalRects = criticalRects
        self.interestingRects = interestingRects
        self.readRects = readRects
    }
    
    /// Sets the last rectangle (and on which page) that was added / removed
    func setLastRect(lastRect: NSRect, lastPage: PDFPage) {
        self.lastRect = lastRect
        self.lastPage = lastPage
    }
    
    /// Returns the last rectangle (if it exists). In the current implementation, this should never return nil.
    func getLastRect() -> (lastRect: NSRect, lastPage: PDFPage)? {
        if let lp = self.lastPage {
            return (self.lastRect!, self.lastPage!)
        } else {
            return nil
        }
    }
}

/// Implementation of a custom PDFView class, used to implement additional function related to
/// psychophysiology and user activity tracking
class MyPDF: PDFView {
    
    var containsRawString = false  // this stores whether the document actually contains scanned text
    
    /// Stores the information element for the current document.
    /// Set by DocumentWindowController.loadDocument()
    var infoElem: DocumentInformationElement?

    // MARK: - Markings (will be translated to annotations)
    
    /// Stores all rectangles marked as "critical"
    var criticalRects = [PDFPage: [NSRect]]()
    
    /// Stores all rectangles marked as "interesting"
    var interestingRects = [PDFPage: [NSRect]]()
    
    /// Stores all rectangles marked as "read"
    var readRects = [PDFPage: [NSRect]]()
    
    // MARK: - Event callbacks
    
    /// To receive single click actions (create "read" mark)
    override func mouseDown(theEvent: NSEvent) {
        let singleClickTestingMode = false  // set this to true if we want to redirect single clicks
        if singleClickTestingMode {
        // Only proceed if there is actually text to select
            if theEvent.clickCount == 1 {
                if containsRawString {
                    // -- OLD STARTS HERE
    //                // Mouse in display view coordinates.
    //                var mouseDownLoc = self.convertPoint(theEvent.locationInWindow, fromView: nil)
    //                markAndAnnotate(mouseDownLoc, importance: Importance.Read)
                    // -- OLD ENDS HERE
                    
                    /// GETTING MOUSE LOCATION IN WINDOW FROM SCREEN COORDINATES
                    // get mouse in screen coordinates
                    let mouseLoc = NSEvent.mouseLocation()
                    for screen in NSScreen.screens() as! [NSScreen] {
                        if NSMouseInRect(mouseLoc, screen.frame, false) {
                            let tinySize = NSSize(width: 1, height: 1)
                            let mouseRect = NSRect(origin: mouseLoc, size: tinySize)
                            //let rawLocation = screen.convertRectToBacking(mouseRect)
                            
                            // use raw location to map back into view coordinates
                            let mouseInWindow = self.window!.convertRectFromScreen(mouseRect)
                            let mouseInView = self.convertRect(mouseInWindow, fromView: self.window!.contentViewController!.view)
                            markAndAnnotate(mouseInView.origin, importance: Importance.Read)
                        }
                    }
                } else {
                    super.mouseDown(theEvent)
                }
            }
        } else {
            super.mouseDown(theEvent)
        }
    }
    
    // MARK: - Markings and Annotations
    
    /// Manually set all rectangles to the given parameters, and annotate them.
    func setMarksAndAnnotate(criticalRects: [PDFPage: [NSRect]], interestingRects: [PDFPage: [NSRect]], readRects: [PDFPage: [NSRect]]) {
        self.criticalRects = criticalRects
        self.interestingRects = interestingRects
        self.readRects = readRects
        autoAnnotate()
    }
    
    /// This method is called (so far) only by the undo manager. It sets the state of markings to the specified object (markingState) and
    /// refreshes the view on the marking corresponding to the last rectangle's property of the given marking state (so that the last
    /// added / removed rectangle can be seen appearing / disappearing immediately).
    @objc func undoMarkAndAnnotate(previousState: MarkingState) {
        // a last tuple must be present, otherwise it should not have been added in the first place
        if let lastTuple = previousState.getLastRect() {
            
            // store previous state before making any modification
            let evenPreviousState = MarkingState(criticalRects: self.criticalRects, interestingRects: self.interestingRects, readRects: self.readRects)
            
            // apply previous state and perform annotations
            self.criticalRects = previousState.criticalRects
            self.interestingRects = previousState.interestingRects
            self.readRects = previousState.readRects
            autoAnnotate()
        
            // show this change
            let annotRect = annotationRectForMark(lastTuple.lastRect, page: lastTuple.lastPage)
            refreshForAnnotation(annotRect, page: lastTuple.lastPage)
            
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
    /// :param: location The point for which a rect will be created
    /// :param: importance The importance of the rect that will be created
    func markAndAnnotate(location: NSPoint, importance: Importance) {
        if containsRawString {
            // prepare a marking state to store this operation
            let previousState = MarkingState(criticalRects: self.criticalRects, interestingRects: self.interestingRects, readRects: self.readRects)
            let newTuple = mark(location, importance: importance)
            // if noting was done (i.e. vertical line) do nothing, otherwise store state and annotate
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
    /// :returns: A triplet containing the rectangle that was created, on which page it was created and what importance
    func mark(locationInView: NSPoint, importance: Importance) -> (newRect: NSRect, onPage: PDFPage, importance: Importance)? {
        var markRect: NSRect
        
        // Page we're on.
        var activePage = self.pageForPoint(locationInView, nearest: true)
        
        // Get mouse in "page space".
        let pagePoint = self.convertPoint(locationInView, toPage: activePage)
        
        let pointArray = verticalFocalPoints(fromPoint: pagePoint, self.scaleFactor(), self.getPageRect(activePage))
        
        // if using columns, selection can "bleed" into footers and headers
        // solution: check the median height and median width of each selection, and discard
        // everything which is lineAutoSelectionTolerance bigger than that
        var selections = [PDFSelection]()
        for point in pointArray {
            selections.append(activePage.selectionForLineAtPoint(point))
        }
        
        let medI = selections.count / 2  // median point for selection array
        
        // sort selections by height and get median height
        selections.sort({$0.boundsForPage(activePage).height > $1.boundsForPage(activePage).height})
        let medianHeight = selections[medI].boundsForPage(activePage).height
        
        // sort selections by width and get median width
        selections.sort({$0.boundsForPage(activePage).width > $1.boundsForPage(activePage).width})
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
            let nOfExtraLines: Int = Int(floor(CGFloat(count(selLines)) / CGFloat(extraLineAmount)))
            
            // split selection into beginning / end separating by new line
            
            // only proceed if there are extra lines
            if nOfExtraLines > 0 {
                var lineStartIndex = 0
                // check if part before new line is included in any of the extra beginning lines,
                // if so skip them
                for i in 0..<nOfExtraLines {
                    let currentLineSel = selLines[i] as! PDFSelection
                    let cLString = currentLineSel.string() + "\r"
                    if let cutRange = activePage.string().rangeOfString(cLString) {
                        lineStartIndex = i+1
                        break
                    }
                }
                
                // do the same for the ending part
                var lineEndIndex = count(selLines)-1
                for i in reverse(count(selLines)-1-nOfExtraLines..<count(selLines)) {
                    let currentLineSel = selLines[i] as! PDFSelection
                    let cLString = currentLineSel.string() + "\r"
                    if let cutRange = activePage.string().rangeOfString(cLString) {
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
        }
        
        // The new rectangle for this mark
        markRect = pdfSel.boundsForPage(activePage)
        
        // Single click adds a read rect, double click an interesting rect
        switch importance {
        case .Read:
            if readRects[activePage] == nil {
                readRects[activePage] = [NSRect]()
            }
            readRects[activePage]!.append(markRect)
        case .Important:
            if interestingRects[activePage] == nil {
                interestingRects[activePage] = [NSRect]()
            }
            interestingRects[activePage]!.append(markRect)
        case .Critical:
            if criticalRects[activePage] == nil {
                criticalRects[activePage] = [NSRect]()
            }
            criticalRects[activePage]!.append(markRect)
        default:
            let exception = NSException(name: "This should never happen!", reason: "Imporance enum non-existent", userInfo: nil)
            exception.raise()
        }
        return (markRect, activePage, importance)
    }
    
    /// Remove all annotations which are a line and match the annotations colours
    /// defined in PeyeConstants
    func removeAllAnnotations() {
        for i in 0..<document()!.pageCount() {
            let page = document()!.pageAtIndex(i)
            for annColour in PeyeConstants.annotationAllColours {
                for annotation in page.annotations() {
                    if let annotation = annotation as? PDFAnnotationLine {
                        if annotation.color().practicallyEqual(annColour) {
                            page.removeAnnotation(annotation)
                        }
                    }
                }
            }
        }
    }
    
    /// Create PDFAnnotationLines related to the specified rectangle dictionary (markings)
    /// (whieh contains locations of "interesting or read rectangles") on all pages
    ///
    /// :param: rectDict The rectangle dictionary
    /// :param: colour The color to use, generally defined in PeyeConstants
    /// :returns: A copy of the updated dictionary, after union/intersection
    func outputAnnotations(rectDict: [PDFPage: [NSRect]], colour: NSColor) -> [PDFPage: [NSRect]] {
        let lineThickness: CGFloat = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefAnnotationLineThickness) as! CGFloat
        let myBord = PDFBorder()
        myBord.setLineWidth(lineThickness)
        
        var returnDictionary = rectDict
        for page in rectDict.keys {
            let unitedRects = uniteCollidingRects(rectDict[page]!)
            returnDictionary[page]! = unitedRects
            for rect in unitedRects {
                let newRect = annotationRectForMark(rect, page: page)
                let annotation = PDFAnnotationLine(bounds: newRect)
                annotation.setColor(colour)
                annotation.setBorder(myBord)
                page.addAnnotation(annotation)
                
                // tell the view to immediately refresh itself in an area which includes the
                // line's "border"
                refreshForAnnotation(newRect, page: page)
            }
        }
        return returnDictionary
    }
    
    /// Writes all annotations corresponding to all marks, and deletes intersecting rectangles for "lower-class" rectangles which
    /// intersect with "higher-class" rectangles
    func autoAnnotate() {
        removeAllAnnotations()
        criticalRects = outputAnnotations(criticalRects, colour: PeyeConstants.annotationColourCritical)
        // Subtract critical rects from interesting and read rects
        for page in interestingRects.keys {
            var unitedRects = uniteCollidingRects(interestingRects[page]!)
            if let cRects = criticalRects[page] {  // continue only if there is something to subtract
                interestingRects[page]! = subtractRectangles(interestingRects[page]!, cRects)
            }
        }
        for page in readRects.keys {
            var unitedRects = uniteCollidingRects(readRects[page]!)
            if let cRects = criticalRects[page] {  // continue only if there is something to subtract
                readRects[page]! = subtractRectangles(readRects[page]!, cRects)
            }
        }
        interestingRects = outputAnnotations(interestingRects, colour: PeyeConstants.annotationColourInteresting)
        // Subtract (remaining) interesting rects from read rects
        for page in readRects.keys {
            var unitedRects = uniteCollidingRects(readRects[page]!)
            if let iRects = interestingRects[page] {  // continue only if there is something to subtract
                readRects[page]! = subtractRectangles(readRects[page]!, iRects)
            }
        }
        readRects = outputAnnotations(readRects, colour: PeyeConstants.annotationColourRead)
        // Placeholder for a better way to enable this
        NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "autoAnnotateCallback", userInfo: nil, repeats: false)
    }
    
    @objc func autoAnnotateCallback() {
        NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.autoAnnotationComplete, object: self)
    }
    
    /// Refreshes the annotation for the given rectangle, which was added / deleted, taking into consideration annotation's line thickness
    ///
    /// :param: annotationRect The rectangle covering the actual annotation in view coordinates
    /// :param: page The page on which the annotation resides
    func refreshForAnnotation(annotationRect: NSRect, page: PDFPage) {
        // tell the view to immediately refresh itself in an area which includes the
        // line's "border"
        let lineThickness: CGFloat = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefAnnotationLineThickness) as! CGFloat
        var rectIncludingThickness = annotationRect
        rectIncludingThickness.origin.x -= lineThickness / 2
        rectIncludingThickness.size.width = lineThickness
        setNeedsDisplayInRect(convertRect(rectIncludingThickness, fromPage: page))
    }
    
    /// Returns a rectangle corresponding to the annotation for a rectangle corresponding to the mark, using all appropriate constants / preferences.
    ///
    /// :param: markRect The rectangle corresponding to the mark
    /// :param: page The page on which the mark resides, and on which the annotation will be created
    /// :returns: A rectangle representing the annotation
    func annotationRectForMark(markRect: NSRect, page: PDFPage) -> NSRect {
        let newRect_x = markRect.origin.x - PeyeConstants.annotationLineDistance
        let newRect_y = markRect.origin.y
        let newRect_height = markRect.height
        let newRect_width: CGFloat = 1.0
        return NSRect(x: newRect_x, y: newRect_y, width: newRect_width, height: newRect_height)
    }
    
    
    // MARK: - General accessor methods
    
    /// Get media box for page, representing coordinates which take into account if
    /// page has been cropped (in Preview, for example). By default returns
    /// media box instead if crop box is not present, which is what we want
    func getPageRect(page: PDFPage) -> NSRect {
        return page.boundsForBox(kPDFDisplayBoxCropBox)
    }
   
    /// Get proportion of document currently being seen, as a pair of numbers from
    /// 0 to 1 (e.g. 0, 0.25 means that we are observing the first quarter of a document, or whole page 1 out of 4).
    /// Note: this is biased in excess (for example if we are seeing two pages side-by-side it returns the smallest min and the highest max possible).
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
        let mspace = PeyeConstants.extraMargin
        let visiblePages = self.visiblePages()
        var visibleRects = [NSRect]()  // rects in page coordinates, one for each page, representing visible portion
        
        for visiblePage in visiblePages as! [PDFPage] {
            
            // Get page's rectangle coordinates
            var pageRect = getPageRect(visiblePage)
            
            // Get viewport rect and apply margin
            var visibleRect = NSRect(origin: CGPoint(x: 0, y: 0), size: self.frame.size)
            visibleRect.inset(dx: PeyeConstants.extraMargin, dy: PeyeConstants.extraMargin)
            
            visibleRect = self.convertRect(visibleRect, toPage: visiblePage)  // Convert rect to page coordinates
            visibleRect.intersect(pageRect)  // Intersect to get seen portion
            visibleRects.append(visibleRect)
            
        }
        return visibleRects
    }
    
    /// Returns the visible text as a string, or nil if no text can be fetched.
    func getVisibleString() -> NSString? {
        // Only proceed if there is actually text to select
        if containsRawString {
            let mspace = PeyeConstants.extraMargin
            let visiblePages = self.visiblePages()
            let generatedSelection = PDFSelection(document: self.document())
            var visibleRects = [NSRect]()  // rects in page coordinates, one for each page, representing visible portion
            
            for visiblePage in visiblePages as! [PDFPage] {
                
                // Get page's rectangle coordinates
                var pageRect = getPageRect(visiblePage)
                
                // Get viewport rect and apply margin
                var visibleRect = NSRect(origin: CGPoint(x: 0, y: 0), size: self.frame.size)
                visibleRect.inset(dx: PeyeConstants.extraMargin, dy: PeyeConstants.extraMargin)
                
                visibleRect = self.convertRect(visibleRect, toPage: visiblePage)  // Convert rect to page coordinates
                visibleRect.intersect(pageRect)  // Intersect to get seen portion
                
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
            let mspace = PeyeConstants.extraMargin
            let visiblePages = self.visiblePages()
            let generatedSelection = PDFSelection(document: self.document())
            var visibleRects = [NSRect]()  // rects in page coordinates, one for each page, representing visible portion
            
            for visiblePage in visiblePages as! [PDFPage] {
                
                // Get page's rectangle coordinates
                var pageRect = getPageRect(visiblePage)
                
                // Get viewport rect and apply margin
                var visibleRect = NSRect(origin: CGPoint(x: 0, y: 0), size: self.frame.size)
                visibleRect.inset(dx: PeyeConstants.extraMargin, dy: PeyeConstants.extraMargin)
                
                visibleRect = self.convertRect(visibleRect, toPage: visiblePage)  // Convert rect to page coordinates
                visibleRect.intersect(pageRect)  // Intersect to get seen portion
                
                generatedSelection.addSelection(visiblePage.selectionForRect(visibleRect))
            }
            
            self.setCurrentSelection(generatedSelection, animate: true)
        }
    }
    
    /// Returns the current status (i.e. converts the current viewport to a reading event.)
    ///
    /// :returns: The reading event for the current status, or nil if nothing is actually visible
    func getStatus() -> ReadingEvent? {
        if self.visiblePages() != nil {
            let multiPage: Bool = (count(self.visiblePages())) > 1
            let visiblePageLabels: [String] = getVisiblePageLabels()
            let visiblePageNums: [Int] = getVisiblePageNums()
            let pageRects: [NSRect] = getVisibleRects()
            let proportion: DiMeRange = getProportion()
            var plainTextContent: NSString = ""
            
            if let textContent = getVisibleString() {
                plainTextContent = textContent
            }
            
            var readingRects = [ReadingRect]()
            for rect in pageRects {
                var newRect = ReadingRect(rect: rect, readingClass: PeyeConstants.CLASS_VIEWPORT)
                readingRects.append(newRect)
            }
            
            return ReadingEvent(multiPage: multiPage, visiblePageNumbers: visiblePageNums, visiblePageLabels: visiblePageLabels, pageRects: readingRects, proportion: proportion, plainTextContent: plainTextContent, infoElemId: infoElem!.id)
        } else {
            return nil
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
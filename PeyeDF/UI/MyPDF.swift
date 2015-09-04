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

/// Implementation of a custom PDFView class, used to implement additional function related to
/// psychophysiology and user activity tracking
class MyPDF: PDFView {
    
    /// Stores all rectangles marked as "interesting"
    var interestingRects = [PDFPage: [NSRect]]()
    
    /// Stores all rectangles marked as "read"
    var readRects = [PDFPage: [NSRect]]()
    
    var containsRawString = false  // this stores whether the document actually contains scanned text
    
    /// Stores the information element for the current document.
    /// Set by DocumentWindowController.loadDocument()
    var infoElem: DocumentInformationElement?

    // MARK: - Event callbacks
    
    /// To receive single click actions
    override func mouseDown(theEvent: NSEvent) {
        // Only proceed if there is actually text to select
        if containsRawString {
            // Mouse in display view coordinates.
            var mouseDownLoc = self.convertPoint(theEvent.locationInWindow, fromView: nil)
            annotate(mouseDownLoc, importance: Importance.Read)
        } else {
            super.mouseDown(theEvent)
        }
    }
    
    /// To receive double click actions from the recognizer
    func doubleClick(location: NSPoint) {
        // Only proceed if there is actually text to select
        if containsRawString {
            annotate(location, importance: Importance.Important)
        }
    }
    
    // MARK: - Annotations
    
    /// Manually tell that a point (and hence the paragraph/subparagraph related to it
    /// should be marked as somehow important
    func annotate(locationInView: NSPoint, importance: Importance) {
        
        // Page we're on.
        var activePage = self.pageForPoint(locationInView, nearest: true)
        
        // Get mouse in "page space".
        let pagePoint = self.convertPoint(locationInView, toPage: activePage)
        
        let pointArray = multiVPoint(pagePoint, self.scaleFactor())
        
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
            return
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
        
        // Single click adds a read rect, double click an interesting rect
        switch importance {
        case .Read:
            if readRects[activePage] == nil {
                readRects[activePage] = [NSRect]()
            }
            readRects[activePage]!.append(pdfSel.boundsForPage(activePage))
        case .Important:
            if interestingRects[activePage] == nil {
                interestingRects[activePage] = [NSRect]()
            }
            interestingRects[activePage]!.append(pdfSel.boundsForPage(activePage))
        default:
            return
        }
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
    
    /// Create PDFAnnotationLines related to the specified rectangle dictionary
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
                var newRect: NSRect
                let newRect_x = rect.origin.x - PeyeConstants.annotationLineDistance
                let newRect_y = rect.origin.y
                let newRect_height = rect.height
                let newRect_width: CGFloat = 1.0
                newRect = NSRect(x: newRect_x, y: newRect_y, width: newRect_width, height: newRect_height)
                let annotation = PDFAnnotationLine(bounds: newRect)
                annotation.setColor(colour)
                annotation.setBorder(myBord)
                page.addAnnotation(annotation)
                
                // tell the view to immediately refresh itself in an area which includes the
                // line's "border"
                var rectIncludingThickness = newRect
                rectIncludingThickness.origin.x -= lineThickness / 2
                rectIncludingThickness.size.width = lineThickness
                setNeedsDisplayInRect(convertRect(rectIncludingThickness, fromPage: page))
            }
        }
        return returnDictionary
    }
    
    func autoAnnotate() {
        removeAllAnnotations()
        interestingRects = outputAnnotations(interestingRects, colour: PeyeConstants.annotationColourInteresting)
        // Subtract interesting rects from read rects first
        for page in readRects.keys {
            var unitedRects = uniteCollidingRects(readRects[page]!)
            var collidingRects: [(rRect: NSRect, iRect: NSRect)] = [] // tuple with read rects and interesting rects which intersect
            if let iRects = interestingRects[page] {
                var i = 0
                while i < count(unitedRects) {
                    let rRect = unitedRects[i]
                    for iRect in iRects {
                        if NSIntersectsRect(rRect, iRect) {
                            collidingRects.append((rRect: rRect, iRect: iRect))
                            unitedRects.removeAtIndex(i)
                            continue
                        }
                    }
                    ++i
                }
            }
            for (rRect, iRect) in collidingRects {
                unitedRects.extend(rRect.subtractRect(iRect))
            }
            readRects[page]! = unitedRects
        }
        readRects = outputAnnotations(readRects, colour: PeyeConstants.annotationColourRead)
        // Placeholder for a better way to enable this
        NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "autoAnnotateCallback", userInfo: nil, repeats: false)
    }
    
    @objc func autoAnnotateCallback() {
        NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.autoAnnotationComplete, object: self)
    }
    
    
    // MARK: - General accessor methods
    
    /// Return size of a page (the current page).
    func pageSize() -> NSSize {
        return self.rowSizeForPage(self.currentPage())
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
        let plainTextContent: NSString = getVisibleString()!
        
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
    
    @IBAction func test(sender: AnyObject?) {
        
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
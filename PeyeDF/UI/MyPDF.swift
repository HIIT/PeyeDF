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

/// Implementation of a custom PDFView class, used to implement additional function related to
/// psychophysiology and user activity tracking
class MyPDF: PDFView {
    
    var containsRawString = false  // this stores whether the document actually contains scanned text
    
    /// Stores the information element for the current document.
    /// Set by DocumentWindowController.loadDocument()
    var infoElem: DocumentInformationElement?
    
    override func mouseDown(theEvent: NSEvent) {
        // Only proceed if there is actually text to select
        if containsRawString {
            // Mouse in display view coordinates.
            var mouseDownLoc = self.convertPoint(theEvent.locationInWindow, fromView: nil)
            
            // Page we're on.
            var activePage = self.pageForPoint(mouseDownLoc, nearest: true)
            
            // Get mouse in "page space".
            let pagePoint = self.convertPoint(mouseDownLoc, toPage: activePage)
            
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
            self.setCurrentSelection(pdfSel, animate: true)
            // TODO: Remove this
            if !(CGRectIsEmpty(pdfSel.boundsForPage(activePage))) {
                NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.selectionNotification, object: self)
            }
        } else {
            super.mouseDown(theEvent)
        }
    }
    
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
    
    /// Get the number of visible pages, starting from zero
    func getVisiblePageNums() -> [Int] {
        var visibleArray = [Int]()
        for visiblePage in self.visiblePages() as! [PDFPage] {
            visibleArray.append(visiblePage.label().toInt()!)
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
    
    // MARK: Debug functions
    
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
    
    func getStatus() -> ReadingEvent {
        let multiPage: Bool = (count(self.visiblePages())) > 1
        let visiblePages: [Int] = getVisiblePageNums()
        let pageRects: [NSRect] = getVisibleRects()
        let proportion: DiMeRange = getProportion()
        let plainTextContent: NSString = getVisibleString()!
        
        return ReadingEvent(multiPage: multiPage, visiblePages: visiblePages, pageRects: pageRects, proportion: proportion, plainTextContent: plainTextContent, infoElemId: infoElem!.id)
    }
    
}
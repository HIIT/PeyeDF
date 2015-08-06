//
//  PDF.swift
//  PeyeDF
//
//  Created by Marco Filetti on 10/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa
import Quartz.PDFKit

// Constants
let extraLineAmount = 3 // 1/this number is the amount of extra lines that we want to discard
                        // if we are at beginning or end of paragraph

/// Implementation of a custom PDFView class, used to implement additional function related to
/// psychophysiology and user activity tracking
class MyPDF:PDFView {
    
    var containsRawString = false  // this stores whether the document actually contains scanned text
    
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
            
            var pdfSel = PDFSelection(document: self.document())
            for point in pointArray {
                pdfSel.addSelection(activePage.selectionForLineAtPoint(point))
            }
            // TODO: if using columns, selection can "bleed" into footers and headers
            // solution: check which width the majority of lines have, and don't go away from this
            
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
        }
    }
    
    /// Return size of a page (the current page).
    func pageSize() -> NSSize {
        return self.rowSizeForPage(self.currentPage())
    }
}
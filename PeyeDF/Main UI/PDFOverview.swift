//
// Copyright (c) 2015 Aalto University
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

import Cocoa
import Quartz
import Foundation

private let maskColour = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.2)

/// Extends the basic pdf support to allow an overview of a document
class PDFOverview: PDFBase {
    
    /// The pdf view which is linked to this overview.
    /// Setting this value causes a refresh (and resets zoom).
    weak var pdfDetail: PDFBase? { didSet {
        if let pdfb = pdfDetail, let pdfDoc = pdfb.document, let pdfUrl = pdfDoc.documentURL {
            self.document = PDFDocument(URL: pdfUrl)
            self.scaleFactor = 0.2
            self.scrollToBeginningOfDocument(self)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(pdfDetailHasNewPage(_:)), name: PDFViewPageChangedNotification, object: pdfDetail)
        } else {
            self.document = nil
        }
        self.refreshAll()
    } }
    
    /// The page at this index will be "highlighted" (whiter than the others).
    var highlightPage = 0 { didSet {
        // Changing this value will cause a display refresh (if old is different than new value).
        if oldValue != highlightPage {
            self.refreshPage(atIndex: oldValue)
            self.refreshPage(atIndex: highlightPage)
        }
    } }
    
    /// Whether we want to draw rect which were simply gazed upon (useful for debugging)
    var drawGazedRects: Bool { get {
        return NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefRefinderDrawGazedUpon) as! Bool
    } }
    
    // MARK: - Page drawing
    
    /// Draw markings on page as bezier paths with their corresponding colour
    override func drawPage(page: PDFPage) {
    	// Let PDFView do most of the hard work.
        super.drawPage(page)
        
        // get difference between media and crop box
        let pointDiff = offSetToCropBox(page)
        
        let pageIndex = self.document!.indexForPage(page)
        
        // draw gray mask if this page is not the highlight page
        if pageIndex != highlightPage {
            // Save.
            NSGraphicsContext.saveGraphicsState()
            
            // Draw.
            let pageRect = self.getPageRect(page)
            let rectPath: NSBezierPath = NSBezierPath(rect: pageRect.offset(byPoint: pointDiff))
            maskColour.setFill()
            rectPath.fill()
            
            // Restore.
            NSGraphicsContext.restoreGraphicsState()
        }
        
        // draw gazed upon rects if desired
        if drawGazedRects {
            let rectsToDraw = markings.get(ofClass: .Paragraph, forPage: pageIndex)
            if rectsToDraw.count > 0 {
                // Save.
                NSGraphicsContext.saveGraphicsState()
                
                // Draw.
                for rect in rectsToDraw {
                    // if rect has an attention value, use that instead of the default color
                    let rectCol: NSColor
                    if let av = rect.attnVal {
                        rectCol = PeyeConstants.colourAttnVal(av)
                    } else {
                        rectCol = PeyeConstants.smiColours[.Paragraph]!.colorWithAlphaComponent(0.9)
                    }
                    let adjRect = rect.rect.offset(byPoint: pointDiff)
                    let rectPath: NSBezierPath = NSBezierPath(rect: adjRect)
                    rectCol.setFill()
                    rectPath.fill()
                }
                
                // Restore.
                NSGraphicsContext.restoreGraphicsState()
            }
            
        } else {
        // If we don't want to display gazed rects - display "normal" annotations instead
        
            // cycle through annotation classes
            let cycleClasses = [ReadingClass.Low, ReadingClass.Medium, ReadingClass.High]
            
            let pageIndex = self.document!.indexForPage(page)
            for rc in cycleClasses {
                let rectsToDraw = markings.get(ofClass: rc, forPage: pageIndex)
                if rectsToDraw.count > 0 {
                	// Save.
                    NSGraphicsContext.saveGraphicsState()
            	
                    // Draw.
                    for rect in rectsToDraw {
                        if let colour = markAnnotationColours[rc] {
                            let rectCol = colour.colorWithAlphaComponent(0.9)
                            let adjRect = rect.rect.offset(byPoint: pointDiff)
                            let rectPath: NSBezierPath = NSBezierPath(rect: adjRect)
                            rectCol.setFill()
                            rectPath.fill()
                        } else {
                            AppSingleton.log.error("Could not find an appropriate colour for reading class: \(rc.rawValue)")
                        }
                    }
                    
                	// Restore.
                	NSGraphicsContext.restoreGraphicsState()
                }
            }
            
            // draw found search queries
            let rectsToDraw = markings.get(ofClass: .FoundString, forPage: pageIndex)
            if rectsToDraw.count > 0{
            	// Save.
                NSGraphicsContext.saveGraphicsState()
        	
                // Draw.
                for rect in rectsToDraw {
                    let rectCol = PeyeConstants.colourFoundStrings
                    // scale rect up to make it more visible
                    let rectPath: NSBezierPath = NSBezierPath(rect: rect.rect.scale(3))
                    rectCol.setFill()
                    rectPath.fill()
                }
                
            	// Restore.
            	NSGraphicsContext.restoreGraphicsState()
            }
            
        }

    }
    
    /// Single click to scroll pdfDetail to the desired point
    override func mouseDown(theEvent: NSEvent) {
        guard let doc = self.document else {
            return
        }
        
        let piw = theEvent.locationInWindow
        let mouseInView = self.convertPoint(piw, fromView: nil)
        
        // Page we're on.
        let activePage = self.pageForPoint(mouseInView, nearest: true)
        
        // Index for current page
        let pageIndex = doc.indexForPage(activePage!)

        // Get location in "page space".
        let pagePoint = self.convertPoint(mouseInView, toPage: activePage!)
        
        pdfDetail?.focusOn(FocusArea(forPoint: pagePoint, onPage: pageIndex), delay: 0)
    }
    
    /// Called when the pdfDetail associated to this overview lands on a new current page
    @objc func pdfDetailHasNewPage(notification: NSNotification) {
        guard let mypdb = notification.object as? PDFBase, doc = mypdb.document else {
            return
        }
        let newCurrentPage = mypdb.currentPage
        let cpi = doc.indexForPage(newCurrentPage!)
        highlightPage = cpi
    }
    
}

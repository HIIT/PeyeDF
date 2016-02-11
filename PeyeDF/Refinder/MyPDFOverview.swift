//
//  MyPDFOverview.swift
//  PeyeDF
//
//  Created by Marco Filetti on 04/11/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Cocoa
import Quartz
import Foundation

/// Extends the basic pdf support to allow an overview of a document
class MyPDFOverview: MyPDFBase {
    
    weak var pdfDetail: MyPDFDetail?
    
    /// Whether we want to draw rect which were simply gazed upon (useful for debugging)
    var drawGazedRects: Bool = {
        return NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefRefinderDrawGazedUpon) as! Bool
    }()
    
    // MARK: - Page drawing override
    
    /// Draw markings on page as bezier paths with their corresponding colour
    override func drawPage(page: PDFPage!) {
    	// Let PDFView do most of the hard work.
        super.drawPage(page)
        
        // if origins of media and boxes are different, obtain difference
        // to later apply it to each readingrect's origin
        let mediaBoxo = page.boundsForBox(kPDFDisplayBoxMediaBox).origin
        let cropBoxo = page.boundsForBox(kPDFDisplayBoxCropBox).origin
        var pointDiff = NSPoint(x: 0, y: 0)
        if mediaBoxo != cropBoxo {
            pointDiff.x = mediaBoxo.x - cropBoxo.x
            pointDiff.y = mediaBoxo.y - cropBoxo.y
        }
        
        // draw gazed upon rects if desired
        if drawGazedRects {
            let pageIndex = self.document().indexForPage(page)
            let rectsToDraw = markings.get(ofClass: .Paragraph, forPage: pageIndex)
            if rectsToDraw.count > 0 {
                // Save.
                NSGraphicsContext.saveGraphicsState()
                
                // Draw.
                for rect in rectsToDraw {
                    let rectCol = PeyeConstants.smiColours[.Paragraph]!.colorWithAlphaComponent(0.9)
                    let adjRect = rect.rect.offset(byPoint: pointDiff)
                    let rectPath: NSBezierPath = NSBezierPath(rect: adjRect)
                    rectCol.setFill()
                    rectPath.fill()
                }
                
                // Restore.
                NSGraphicsContext.restoreGraphicsState()
            }
            
        }
        
        // cycle through annotation classes
        let cycleClasses = [ReadingClass.Read, ReadingClass.Interesting, ReadingClass.Critical]
        
        let pageIndex = self.document().indexForPage(page)
        for rc in cycleClasses {
            let rectsToDraw = markings.get(ofClass: rc, forPage: pageIndex)
            if rectsToDraw.count > 0 {
            	// Save.
                NSGraphicsContext.saveGraphicsState()
        	
                // Draw.
                for rect in rectsToDraw {
                    let rectCol = PeyeConstants.annotationColours[rc]!.colorWithAlphaComponent(0.9)
                    let adjRect = rect.rect.offset(byPoint: pointDiff)
                    let rectPath: NSBezierPath = NSBezierPath(rect: adjRect)
                    rectCol.setFill()
                    rectPath.fill()
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
                let rectCol = PeyeConstants.markColourFoundStrings
                // scale rect up to make it more visible
                let rectPath: NSBezierPath = NSBezierPath(rect: rect.rect.scale(3))
                rectCol.setFill()
                rectPath.fill()
            }
            
        	// Restore.
        	NSGraphicsContext.restoreGraphicsState()
        }
        

    }
    
    
    /// Single click to scroll pdfDetail to the desired point
    override func mouseDown(theEvent: NSEvent) {
        let piw = theEvent.locationInWindow
        let mouseInView = self.convertPoint(piw, fromView: nil)
        
        // Page we're on.
        let activePage = self.pageForPoint(mouseInView, nearest: true)
        
        // Index for current page
        let pageIndex = self.document().indexForPage(activePage)

        // Get location in "page space".
        let pagePoint = self.convertPoint(mouseInView, toPage: activePage)
        
        // Get tiny rect of selected position
        let pointRect = NSRect(origin: pagePoint, size: NSSize())
        
        pdfDetail?.scrollToRect(pointRect, onPageIndex: pageIndex)
    }
}

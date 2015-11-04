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

class MyPDFOverview: MyPDFBase {
    
    weak var pdfDetail: MyPDFDetail?

    // MARK: - Page drawing override
    
    /// Draw markings on page as bezier paths with their corresponding colour
    override func drawPage(page: PDFPage!) {
    	// Let PDFView do most of the hard work.
        super.drawPage(page)
        
        // cycle through annotation classes
        let cycleClasses = [ReadingClass.Read, ReadingClass.Interesting, ReadingClass.Critical]
        
        let pageIndex = self.document().indexForPage(page)
        for rc in cycleClasses {
            if let rectsToDraw = manualMarks.get(rc)[pageIndex] {
            	// Save.
                NSGraphicsContext.saveGraphicsState()
        	
                // Draw.
                for rect in rectsToDraw {
                    let rectCol = PeyeConstants.annotationColours[rc]!.colorWithAlphaComponent(0.9)
                    let rectPath: NSBezierPath = NSBezierPath(rect: rect)
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
        let mouseLoc = NSEvent.mouseLocation()
        for screen in NSScreen.screens() as [NSScreen]! {
            if NSMouseInRect(mouseLoc, screen.frame, false) {
                let tinySize = NSSize(width: 1, height: 1)
                let mouseRect = NSRect(origin: mouseLoc, size: tinySize)
                let mouseInWindow = self.window!.convertRectFromScreen(mouseRect)
                let mouseInView = self.convertRect(mouseInWindow, fromView: self.window!.contentViewController!.view)
                
                // Page we're on.
                let activePage = self.pageForPoint(mouseInView.origin, nearest: true)
                
                // Index for current page
                let pageIndex = self.document().indexForPage(activePage)
        
                // Get location in "page space".
                let pagePoint = self.convertPoint(mouseInView.origin, toPage: activePage)
                
                // Get tiny rect of selected position
                let pointRect = NSRect(origin: pagePoint, size: tinySize)
                
                pdfDetail?.scrollToRect(pointRect, onPageIndex: pageIndex)
            }
        }
    }
}

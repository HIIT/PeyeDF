//
//  RefinderProgressIndicator.swift
//  PeyeDF
//
//  Created by Marco Filetti on 04/11/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Cocoa

class RefinderProgressIndicator: NSView {
    
    /// Progress in a proportion
    var progress = 0.0
    
    /// Class represented by this bar
    var readingC = ReadingClass.Unset

    func setProgress(newProgress: Double, forClass: ReadingClass) {
        self.progress = newProgress
        self.readingC = forClass
    }
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
    
        NSColor.grayColor().setStroke()
        let backPath = NSBezierPath(rect: dirtyRect)
        backPath.lineCapStyle = .RoundLineCapStyle
        backPath.stroke()
        
        var colour = NSColor.whiteColor()
        if readingC == ReadingClass.Read {
            colour = PeyeConstants.annotationColourRead.colorWithAlphaComponent(1)
        } else if readingC == ReadingClass.Interesting {
            colour = PeyeConstants.annotationColourInteresting.colorWithAlphaComponent(1)
        } else if readingC == ReadingClass.Critical {
            colour = PeyeConstants.annotationColourCritical.colorWithAlphaComponent(1)
        }
        
        var rect = dirtyRect
        rect.size.width *= CGFloat(progress)
        let frontPath = NSBezierPath(rect: rect)
        colour.setStroke()
        colour.setFill()
        frontPath.lineCapStyle = .RoundLineCapStyle
        frontPath.stroke()
        frontPath.fill()
    }
    
}

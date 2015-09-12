//
//  Boz.swift
//  PeyeDF
//
//  Created by Marco Filetti on 13/09/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa

/// Class to display a circle (on top of another view)
/// Since this view is on top, hide it! Otherwise will catch events
class CircleOverlay: NSView {
    
    override var acceptsFirstResponder: Bool { return true }
    
    override func drawRect(dirtyRect: NSRect) {
        
        let circleRect = NSRect(origin: NSPoint(x: 25, y: 25), size: NSSize(width: 50, height: 50))
	
        let borderColor = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        borderColor.set()
        
        var circlePath: NSBezierPath = NSBezierPath(ovalInRect: circleRect)
        circlePath.lineWidth = 3.0
        circlePath.stroke()
        
        self.acceptsTouchEvents = false
    }
    
}
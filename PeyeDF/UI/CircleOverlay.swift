//
//  Boz.swift
//  PeyeDF
//
//  Created by Marco Filetti on 13/09/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa

/// Class to display something (e.g. a circle) on top of another view
/// Made to sends events to the view behind it (otherView)
class CircleOverlay: NSView {
    
    /// All events will be redirected to this view
    weak var otherView: NSView?
    
    /// Reject first respnder status
    override var acceptsFirstResponder: Bool { return false }
    
    /// Default circle size
    let kCircleSize = NSSize(width: 30, height: 30)
    
    /// Default circle line width
    let kCircleLineWidth: CGFloat = 3
    
    /// Default circle line colour
    let kCircleLineColour = NSColor(red: 0.9, green: 0.0, blue: 0.0, alpha: 0.8)
    
    /// Default circle position (initially set to a semi random value)
    let circlePosition = NSPoint(x: 30, y: 30)
    
    /// Raise an error if otherView is not set
    override func viewDidMoveToWindow() {
        if otherView == nil {
            let exception = NSException(name: "otherView is not set", reason: "Can't redirect events behind circleOVerlay", userInfo: nil)
            exception.raise()
        }
    }
    
    override func drawRect(dirtyRect: NSRect) {
        
        let circleRect = NSRect(origin: circlePosition, size: kCircleSize)
	
        let borderColor = kCircleLineColour
        borderColor.set()
        
        let circlePath: NSBezierPath = NSBezierPath(ovalInRect: circleRect)
        circlePath.lineWidth = kCircleLineWidth
        circlePath.stroke()
        
        self.acceptsTouchEvents = false
    }
    
    /// Redirect all events to otherView
    override func hitTest(aPoint: NSPoint) -> NSView? {
        return otherView!.hitTest(aPoint)
    }
    
}
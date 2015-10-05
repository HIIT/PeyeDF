//
//  eyeBox.swift
//  eyeViewTest
//
//  Created by Marco Filetti on 24/09/2015.
//  Copyright © 2015 mf. All rights reserved.
//

import Cocoa

/// The eyebox is a simple view that shows the user position as detected by the eye tracker, so participants 
/// can adjust their own position. Uses PeyeConstants.midasEyePositionNotification to track eye position.
class eyeBox: NSBox {
    
    let marginColour = NSColor(red: 0.29, green: 0.29, blue: 0.29, alpha: 1.0)
    
    let boxMargin: CGFloat = 8 // distance of inner box from border in points
    let circleMinSize: CGFloat = 5  // minimum size of eye circle when seen
    
    let minDist:CGFloat = 550  // minimum distance from eye tracker in mm
    let maxDist:CGFloat = 850  // maximum distance from eye tracker in mm
    
    let maxXdelta:CGFloat = 200  // maximum deviation from 0 (absolute value) horizontally
    let maxYdelta:CGFloat = 100  // maximum deviation from 0 (abs val) vertically
    
    var dist: CGFloat = 500
    var xdelta: CGFloat = 0
    var ydelta: CGFloat = 0
    
    override func viewWillMoveToWindow(newWindow: NSWindow?) {
        super.viewWillMoveToWindow(newWindow)
        registerNotification()
    }
    
    deinit {
        unregisterNotification()
    }
    
    func registerNotification() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "newDataReceived:", name: PeyeConstants.midasEyePositionNotification, object: nil)
    }
    
    func unregisterNotification() {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PeyeConstants.midasEyePositionNotification, object: nil)
    }
    
    /// Notification callback
    func newDataReceived(notification: NSNotification) {
        let userInfo = notification.userInfo!
        dist = userInfo["zpos"] as! CGFloat
        xdelta = userInfo["xpos"] as! CGFloat
        ydelta = userInfo["ypos"] as! CGFloat
        self.needsDisplay = true
    }

    /// Draws itself depending on last received position
    override func drawRect(dirtyRect: NSRect) {
        
        // circle max size when dist == maxdist has the radius of half the side size of inner box
        
        super.drawRect(dirtyRect)

        let innerPathSize: CGFloat = frame.width - boxMargin * 2
        let innerPath = NSBezierPath(rect: NSRect(origin: NSPoint(x: boxMargin, y: boxMargin), size: NSSize(width: innerPathSize, height: innerPathSize)))
        
        innerPath.lineWidth = 1
        innerPath.lineJoinStyle = .RoundLineJoinStyle
        
        // 1 is mapped to circleMinSize
        // maxProp is mapped to innerpathsize
        let circleSize = translate(dist, leftMin: minDist, leftMax: maxDist, rightMin: circleMinSize, rightMax: innerPathSize)
        
        
        
        if dist > minDist {
            let circX = getDDelta(xdelta, maxDelta: maxXdelta, maxPos: innerPathSize / 2)
            let circY = getDDelta(ydelta, maxDelta: maxYdelta, maxPos: innerPathSize / 2)
            let centerPoint: CGFloat = frame.width / 2 // center point in the box x and y are the same
            let circleOrigin = NSPoint(x: centerPoint + circX, y: centerPoint + circY)
            let origin = NSPoint(x: circleOrigin.x - circleSize / 2, y: circleOrigin.y - circleSize / 2)
            let circlePath = NSBezierPath(ovalInRect: NSRect(origin: origin, size: NSSize(width: circleSize, height: circleSize)))
            circlePath.stroke()
        }
        
        marginColour.set()
        innerPath.stroke()
    }
    
    /// Translates a raw position (x and/or y) into box position
    private func getDDelta(pos: CGFloat, maxDelta: CGFloat, maxPos: CGFloat) -> CGFloat {
        let isnegative = pos < 0
        let pos = abs(pos)
        let retVal = translate(pos, leftMin: 0, leftMax: maxDelta, rightMin: 0, rightMax: maxPos)
        return isnegative ? -retVal : retVal
    }
    
}

/// Given a value and an input range, return a value in the output range
func translate(value: CGFloat, leftMin: CGFloat, leftMax: CGFloat, rightMin: CGFloat, rightMax: CGFloat) -> CGFloat {
    // Figure out how 'wide' each range is
    let leftSpan = leftMax - leftMin
    let rightSpan = rightMax - rightMin
    
    // Convert the left range into a 0-1 range (float)
    let valueScaled = (value - leftMin) / leftSpan
    
    // Convert the 0-1 range into a value in the right range.
    return rightMin + (valueScaled * rightSpan)
}
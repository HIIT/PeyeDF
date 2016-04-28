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

import Foundation
import Cocoa

/// Draws a "little clock" used to display total reading times
class LittleClock: NSView {
    
    var hours: CGFloat!
    var minutes: CGFloat!
    
    var showClock = false
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        if showClock && hours != nil && minutes != nil {
            drawLittleClock()
        }
    }
    
    func drawLittleClock(frame: NSRect = NSMakeRect(3, 4, 23, 23)) {
        //// General Declarations
        let context = NSGraphicsContext.currentContext()!.CGContext
        
        //// Color Declarations
        let color3 = NSColor(calibratedRed: 0.552, green: 0.552, blue: 0.552, alpha: 1)
        
        //// Variable Declarations
        let hours_rotation: CGFloat = -(hours / 12.0 * 360)
        let minutes_rotation: CGFloat = -(minutes / 60.0 * 360)
        
        //// Oval Drawing
        let ovalPath = NSBezierPath(ovalInRect: NSMakeRect(frame.minX + floor(frame.width * 0.21739 + 0.5), frame.minY + floor(frame.height * 0.21739 + 0.5), floor(frame.width * 0.78261 + 0.5) - floor(frame.width * 0.21739 + 0.5), floor(frame.height * 0.78261 + 0.5) - floor(frame.height * 0.21739 + 0.5)))
        NSColor.blackColor().setStroke()
        ovalPath.lineWidth = 1.5
        ovalPath.stroke()
        
        
        //// Bezier 2 Drawing
        NSGraphicsContext.saveGraphicsState()
        CGContextTranslateCTM(context, frame.minX + 0.50000 * frame.width, frame.minY + 0.50000 * frame.height)
        CGContextRotateCTM(context, (minutes_rotation - 740.311523438) * CGFloat(M_PI) / 180)
        
        let bezier2Path = NSBezierPath()
        bezier2Path.moveToPoint(NSMakePoint(0, 0))
        bezier2Path.curveToPoint(NSMakePoint(0, 6), controlPoint1: NSMakePoint(0, 5.14), controlPoint2: NSMakePoint(0, 6))
        color3.setStroke()
        bezier2Path.lineWidth = 2
        bezier2Path.stroke()
        
        NSGraphicsContext.restoreGraphicsState()
        
        
        //// Bezier Drawing
        NSGraphicsContext.saveGraphicsState()
        CGContextTranslateCTM(context, frame.minX + 0.50000 * frame.width, frame.minY + 0.50000 * frame.height)
        CGContextRotateCTM(context, hours_rotation * CGFloat(M_PI) / 180)
        
        let bezierPath = NSBezierPath()
        bezierPath.moveToPoint(NSMakePoint(0, 0))
        bezierPath.curveToPoint(NSMakePoint(0, 4), controlPoint1: NSMakePoint(0, 3.43), controlPoint2: NSMakePoint(0, 4))
        NSColor.blackColor().setStroke()
        bezierPath.lineWidth = 1.5
        bezierPath.stroke()
        
        NSGraphicsContext.restoreGraphicsState()
    }
}
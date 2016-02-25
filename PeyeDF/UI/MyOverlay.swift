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

import Foundation
import Cocoa

/// Class to display something (e.g. a circle) on top of another view
/// Made to sends events to the view behind it (otherView)
class MyOverlay: NSView {
    
    /// Whether the eye overlay must be drawn
    private(set) lazy var drawOverlay = {return MidasManager.sharedInstance.midasAvailable && MidasManager.sharedInstance.eyesLost}()
    
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
    
    /// Raise an error if otherView is not set and observe notifications
    override func viewDidMoveToWindow() {
        if otherView == nil {
            let exception = NSException(name: "otherView is not set", reason: "Can't redirect events behind circleOVerlay", userInfo: nil)
            exception.raise()
        }
        self.acceptsTouchEvents = false
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "eyeStateCallback:", name: PeyeConstants.eyesAvailabilityNotification, object: MidasManager.sharedInstance)
    }
    
    /// Callback for eye status change (show overlay accordingly)
    @objc private func eyeStateCallback(notification: NSNotification) {
        let uInfo = notification.userInfo as! [String: AnyObject]
        let avail = uInfo["available"] as! Bool
        drawOverlay = !avail
        self.setNeedsDisplayInRect(NSRect(origin: NSPoint(), size: self.frame.size))
    }
    
    override func drawRect(dirtyRect: NSRect) {
        if drawOverlay {
            drawCanvas1(frame2: NSRect(origin: CGPoint(), size: frame.size))
        }
    }
    
    /// Drawing function from PaintCode 2
    func drawCanvas1(frame2 frame2: NSRect = NSMakeRect(73, 77, 743, 726)) {
        let myAlpha: CGFloat = 1.0
        
        //// Color Declarations
        let fillColor = NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: myAlpha)
        let fillColor2 = NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: myAlpha)
        let strokeColor = NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: myAlpha)
        
        
        //// Subframes
        let frame = NSMakeRect(frame2.minX + floor((frame2.width - 621) * 0.52985 + 0.5), frame2.minY + floor((frame2.height - 616) * 0.50000 + 0.5), 621, 616)
        let eyeCrossGroup: NSRect = NSMakeRect(frame.minX + 29.65, frame.minY + 30.1, frame.width - 64.2, frame.height - 57.2)
        
        
        //// Rectangle Drawing
        let rectanglePath = NSBezierPath(rect: NSMakeRect(frame2.minX, frame2.minY, frame2.width, frame2.height))
        fillColor.setFill()
        rectanglePath.fill()
        
        
        //// Eye cross Group
        //// Bezier Drawing
        let bezierPath = NSBezierPath()
        bezierPath.moveToPoint(NSMakePoint(eyeCrossGroup.minX + 0.92803 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.49999 * eyeCrossGroup.height))
        bezierPath.curveToPoint(NSMakePoint(eyeCrossGroup.minX + 0.07018 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.50146 * eyeCrossGroup.height), controlPoint1: NSMakePoint(eyeCrossGroup.minX + 0.66679 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.68105 * eyeCrossGroup.height), controlPoint2: NSMakePoint(eyeCrossGroup.minX + 0.35539 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.67679 * eyeCrossGroup.height))
        bezierPath.curveToPoint(NSMakePoint(eyeCrossGroup.minX + 0.92803 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.50077 * eyeCrossGroup.height), controlPoint1: NSMakePoint(eyeCrossGroup.minX + 0.35539 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.32613 * eyeCrossGroup.height), controlPoint2: NSMakePoint(eyeCrossGroup.minX + 0.66679 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.31971 * eyeCrossGroup.height))
        fillColor2.setFill()
        bezierPath.fill()
        
        
        //// Oval Drawing
        let ovalPath = NSBezierPath(ovalInRect: NSMakeRect(eyeCrossGroup.minX + floor(eyeCrossGroup.width * 0.45564 - 0.2) + 0.7, eyeCrossGroup.minY + floor(eyeCrossGroup.height * 0.45580 - 0.2) + 0.7, floor(eyeCrossGroup.width * 0.54256 + 0.4) - floor(eyeCrossGroup.width * 0.45564 - 0.2) - 0.6, floor(eyeCrossGroup.height * 0.54599 + 0.4) - floor(eyeCrossGroup.height * 0.45580 - 0.2) - 0.6))
        fillColor.setFill()
        ovalPath.fill()
        
        
        //// Bezier 3 Drawing
        let bezier3Path = NSBezierPath()
        bezier3Path.moveToPoint(NSMakePoint(eyeCrossGroup.minX + 1.00000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.50000 * eyeCrossGroup.height))
        bezier3Path.curveToPoint(NSMakePoint(eyeCrossGroup.minX + 0.50000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.00000 * eyeCrossGroup.height), controlPoint1: NSMakePoint(eyeCrossGroup.minX + 1.00000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.22386 * eyeCrossGroup.height), controlPoint2: NSMakePoint(eyeCrossGroup.minX + 0.77614 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.00000 * eyeCrossGroup.height))
        bezier3Path.curveToPoint(NSMakePoint(eyeCrossGroup.minX + 0.00000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.50000 * eyeCrossGroup.height), controlPoint1: NSMakePoint(eyeCrossGroup.minX + 0.22386 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.00000 * eyeCrossGroup.height), controlPoint2: NSMakePoint(eyeCrossGroup.minX + 0.00000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.22386 * eyeCrossGroup.height))
        bezier3Path.curveToPoint(NSMakePoint(eyeCrossGroup.minX + 0.50000 * eyeCrossGroup.width, eyeCrossGroup.minY + 1.00000 * eyeCrossGroup.height), controlPoint1: NSMakePoint(eyeCrossGroup.minX + 0.00000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.77614 * eyeCrossGroup.height), controlPoint2: NSMakePoint(eyeCrossGroup.minX + 0.22386 * eyeCrossGroup.width, eyeCrossGroup.minY + 1.00000 * eyeCrossGroup.height))
        bezier3Path.curveToPoint(NSMakePoint(eyeCrossGroup.minX + 1.00000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.50000 * eyeCrossGroup.height), controlPoint1: NSMakePoint(eyeCrossGroup.minX + 0.77614 * eyeCrossGroup.width, eyeCrossGroup.minY + 1.00000 * eyeCrossGroup.height), controlPoint2: NSMakePoint(eyeCrossGroup.minX + 1.00000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.77614 * eyeCrossGroup.height))
        bezier3Path.closePath()
        bezier3Path.moveToPoint(NSMakePoint(eyeCrossGroup.minX + 0.15220 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.85579 * eyeCrossGroup.height))
        bezier3Path.lineToPoint(NSMakePoint(eyeCrossGroup.minX + 0.84586 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.15281 * eyeCrossGroup.height))
        strokeColor.setStroke()
        bezier3Path.lineWidth = 15
        bezier3Path.stroke()
    }

    
    /// Redirect all events to otherView
    override func hitTest(aPoint: NSPoint) -> NSView? {
        return otherView!.hitTest(aPoint)
    }
    
}
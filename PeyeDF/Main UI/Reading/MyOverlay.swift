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

/// Class to display something on top of another view
/// Made to sends events to the view behind it (otherView).
class MyOverlay: NSView {
    
    /// Whether the eye overlay must be drawn
    fileprivate(set) lazy var drawEyeCross: Bool = {
        if let tracker = AppSingleton.eyeTracker {
            return tracker.available && tracker.eyesLost
        } else {
            return false
        }
    }()
    
    /// Wheter we want to draw the DiMe cross (shown if dime is unavailable)
    fileprivate(set) var drawDiMeCross = false
    
    /// All events will be redirected to this view
    weak var otherView: NSView?
    
    /// Reject first respnder status
    override var acceptsFirstResponder: Bool { return false }
    
    /// Setup overlay and prepare observers. Also checks for dime connection.
    override func viewDidMoveToWindow() {
        
        // basic setup
        if otherView == nil {
            let exception = NSException(name: NSExceptionName(rawValue: "otherView is not set"), reason: "Can't redirect events behind circleOVerlay", userInfo: nil)
            exception.raise()
        }
        self.acceptsTouchEvents = false
        
        // observer for eye state
        NotificationCenter.default.addObserver(self, selector: #selector(eyeStateCallback(_:)), name: PeyeConstants.eyesAvailabilityNotification, object: nil)
        
        // dime connection check
        if !DiMeSession.dimeAvailable {
            DiMeSession.dimeConnect() {
                success, _ in
                
                if !success {
                    DispatchQueue.main.async() {
                        self.drawDiMeCross = true
                        self.needsDisplay = true
                    }
                    
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3.0) {
                        CATransaction.begin()
                        let animateAlpha = CABasicAnimation(keyPath: "opacity")
                        animateAlpha.duration = 2.0
                        animateAlpha.fromValue = 0.5
                        animateAlpha.toValue = 0.0
                        // callback when done
                        CATransaction.setCompletionBlock() {
                            DispatchQueue.main.async() {
                                self.drawDiMeCross = false
                                self.needsDisplay = true
                                self.layer?.opacity = 0.5
                            }
                        }
                        self.layer!.add(animateAlpha, forKey: "animate alpha")
                        CATransaction.commit()
                    }
                }
            }
        }
    }
    
    /// Callback for eye status change (show overlay accordingly)
    @objc fileprivate func eyeStateCallback(_ notification: Notification) {
        let uInfo = (notification as NSNotification).userInfo as! [String: AnyObject]
        let avail = uInfo["available"] as! Bool
        drawEyeCross = !avail
        self.setNeedsDisplay(NSRect(origin: NSPoint(), size: self.frame.size))
    }
    
    /// Redirect all events to otherView
    override func hitTest(_ aPoint: NSPoint) -> NSView? {
        return otherView!.hitTest(aPoint)
    }
    
    // MARK: - Drawing functions
    
    override func draw(_ dirtyRect: NSRect) {
        if drawDiMeCross {
            drawDiMeCrossIn(frame2: NSRect(origin: CGPoint(), size: self.frame.size))
        } else if drawEyeCross {
            drawEyeCrossIn(frame2: NSRect(origin: CGPoint(), size: frame.size))
        }
    }
    
    /// Drawing function for eye cross
    func drawEyeCrossIn(frame2: NSRect = NSMakeRect(73, 77, 743, 726)) {
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
        bezierPath.move(to: NSMakePoint(eyeCrossGroup.minX + 0.92803 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.49999 * eyeCrossGroup.height))
        bezierPath.curve(to: NSMakePoint(eyeCrossGroup.minX + 0.07018 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.50146 * eyeCrossGroup.height), controlPoint1: NSMakePoint(eyeCrossGroup.minX + 0.66679 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.68105 * eyeCrossGroup.height), controlPoint2: NSMakePoint(eyeCrossGroup.minX + 0.35539 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.67679 * eyeCrossGroup.height))
        bezierPath.curve(to: NSMakePoint(eyeCrossGroup.minX + 0.92803 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.50077 * eyeCrossGroup.height), controlPoint1: NSMakePoint(eyeCrossGroup.minX + 0.35539 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.32613 * eyeCrossGroup.height), controlPoint2: NSMakePoint(eyeCrossGroup.minX + 0.66679 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.31971 * eyeCrossGroup.height))
        fillColor2.setFill()
        bezierPath.fill()
        
        //// Oval Drawing
        let ovalPath = NSBezierPath(ovalIn: NSMakeRect(eyeCrossGroup.minX + floor(eyeCrossGroup.width * 0.45564 - 0.2) + 0.7, eyeCrossGroup.minY + floor(eyeCrossGroup.height * 0.45580 - 0.2) + 0.7, floor(eyeCrossGroup.width * 0.54256 + 0.4) - floor(eyeCrossGroup.width * 0.45564 - 0.2) - 0.6, floor(eyeCrossGroup.height * 0.54599 + 0.4) - floor(eyeCrossGroup.height * 0.45580 - 0.2) - 0.6))
        fillColor.setFill()
        ovalPath.fill()
        
        //// Bezier 3 Drawing
        let bezier3Path = NSBezierPath()
        bezier3Path.move(to: NSMakePoint(eyeCrossGroup.minX + 1.00000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.50000 * eyeCrossGroup.height))
        bezier3Path.curve(to: NSMakePoint(eyeCrossGroup.minX + 0.50000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.00000 * eyeCrossGroup.height), controlPoint1: NSMakePoint(eyeCrossGroup.minX + 1.00000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.22386 * eyeCrossGroup.height), controlPoint2: NSMakePoint(eyeCrossGroup.minX + 0.77614 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.00000 * eyeCrossGroup.height))
        bezier3Path.curve(to: NSMakePoint(eyeCrossGroup.minX + 0.00000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.50000 * eyeCrossGroup.height), controlPoint1: NSMakePoint(eyeCrossGroup.minX + 0.22386 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.00000 * eyeCrossGroup.height), controlPoint2: NSMakePoint(eyeCrossGroup.minX + 0.00000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.22386 * eyeCrossGroup.height))
        bezier3Path.curve(to: NSMakePoint(eyeCrossGroup.minX + 0.50000 * eyeCrossGroup.width, eyeCrossGroup.minY + 1.00000 * eyeCrossGroup.height), controlPoint1: NSMakePoint(eyeCrossGroup.minX + 0.00000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.77614 * eyeCrossGroup.height), controlPoint2: NSMakePoint(eyeCrossGroup.minX + 0.22386 * eyeCrossGroup.width, eyeCrossGroup.minY + 1.00000 * eyeCrossGroup.height))
        bezier3Path.curve(to: NSMakePoint(eyeCrossGroup.minX + 1.00000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.50000 * eyeCrossGroup.height), controlPoint1: NSMakePoint(eyeCrossGroup.minX + 0.77614 * eyeCrossGroup.width, eyeCrossGroup.minY + 1.00000 * eyeCrossGroup.height), controlPoint2: NSMakePoint(eyeCrossGroup.minX + 1.00000 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.77614 * eyeCrossGroup.height))
        bezier3Path.close()
        bezier3Path.move(to: NSMakePoint(eyeCrossGroup.minX + 0.15220 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.85579 * eyeCrossGroup.height))
        bezier3Path.line(to: NSMakePoint(eyeCrossGroup.minX + 0.84586 * eyeCrossGroup.width, eyeCrossGroup.minY + 0.15281 * eyeCrossGroup.height))
        strokeColor.setStroke()
        bezier3Path.lineWidth = 15
        bezier3Path.stroke()
    }

    func drawDiMeCrossIn(frame2: NSRect = NSMakeRect(73, 89, 755, 714)) {
        let myAlpha: CGFloat = 1.0
        
        //// Color Declarations
        let fillColor = NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: myAlpha)
        let fillColor2 = NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: myAlpha)
        let strokeColor = NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: myAlpha)

        //// Subframes
        let frame = NSMakeRect(frame2.minX + floor((frame2.width - 621) * 0.52985 + 0.5), frame2.minY + floor((frame2.height - 616) * 0.50000 + 0.5), 621, 616)

        //// Rectangle Drawing
        let rectanglePath = NSBezierPath(rect: NSMakeRect(frame2.minX, frame2.minY, frame2.width, frame2.height))
        fillColor.setFill()
        rectanglePath.fill()

        //// Cross Drawing
        let crossPath = NSBezierPath()
        crossPath.move(to: NSMakePoint(frame.minX + 586.45, frame.maxY - 306.5))
        crossPath.curve(to: NSMakePoint(frame.minX + 308.05, frame.maxY - 585.9), controlPoint1: NSMakePoint(frame.minX + 586.45, frame.maxY - 460.81), controlPoint2: NSMakePoint(frame.minX + 461.81, frame.maxY - 585.9))
        crossPath.curve(to: NSMakePoint(frame.minX + 29.65, frame.maxY - 306.5), controlPoint1: NSMakePoint(frame.minX + 154.29, frame.maxY - 585.9), controlPoint2: NSMakePoint(frame.minX + 29.65, frame.maxY - 460.81))
        crossPath.curve(to: NSMakePoint(frame.minX + 308.05, frame.maxY - 27.1), controlPoint1: NSMakePoint(frame.minX + 29.65, frame.maxY - 152.19), controlPoint2: NSMakePoint(frame.minX + 154.29, frame.maxY - 27.1))
        crossPath.curve(to: NSMakePoint(frame.minX + 586.45, frame.maxY - 306.5), controlPoint1: NSMakePoint(frame.minX + 461.81, frame.maxY - 27.1), controlPoint2: NSMakePoint(frame.minX + 586.45, frame.maxY - 152.19))
        crossPath.close()
        crossPath.move(to: NSMakePoint(frame.minX + 114.4, frame.maxY - 107.68))
        crossPath.line(to: NSMakePoint(frame.minX + 500.62, frame.maxY - 500.51))
        strokeColor.setStroke()
        crossPath.lineWidth = 15
        crossPath.stroke()

        //// Untitled Group
        //// Rectangle 2 Drawing
        let rectangle2Path = NSBezierPath(rect: NSMakeRect(frame.minX + 381.5, frame.minY + frame.height - 346.25, 19.9, 19.9))
        fillColor2.setFill()
        rectangle2Path.fill()

        //// Rectangle 3 Drawing
        let rectangle3Path = NSBezierPath(rect: NSMakeRect(frame.minX + 381.5, frame.minY + frame.height - 304.75, 19.9, 18.9))
        fillColor2.setFill()
        rectangle3Path.fill()

        //// Bezier Drawing
        let bezierPath = NSBezierPath()
        bezierPath.move(to: NSMakePoint(frame.minX + 385.72, frame.maxY - 433.87))
        bezierPath.curve(to: NSMakePoint(frame.minX + 378.32, frame.maxY - 454.56), controlPoint1: NSMakePoint(frame.minX + 385.72, frame.maxY - 440.88), controlPoint2: NSMakePoint(frame.minX + 382.89, frame.maxY - 449.97))
        bezierPath.curve(to: NSMakePoint(frame.minX + 357.72, frame.maxY - 462), controlPoint1: NSMakePoint(frame.minX + 373.75, frame.maxY - 459.16), controlPoint2: NSMakePoint(frame.minX + 364.7, frame.maxY - 462))
        bezierPath.curve(to: NSMakePoint(frame.minX + 337.12, frame.maxY - 454.56), controlPoint1: NSMakePoint(frame.minX + 350.74, frame.maxY - 462), controlPoint2: NSMakePoint(frame.minX + 341.69, frame.maxY - 459.16))
        bezierPath.curve(to: NSMakePoint(frame.minX + 329.72, frame.maxY - 433.87), controlPoint1: NSMakePoint(frame.minX + 332.55, frame.maxY - 449.97), controlPoint2: NSMakePoint(frame.minX + 329.72, frame.maxY - 440.88))
        bezierPath.curve(to: NSMakePoint(frame.minX + 337.12, frame.maxY - 413.18), controlPoint1: NSMakePoint(frame.minX + 329.72, frame.maxY - 426.86), controlPoint2: NSMakePoint(frame.minX + 332.55, frame.maxY - 417.78))
        bezierPath.curve(to: NSMakePoint(frame.minX + 357.72, frame.maxY - 405.75), controlPoint1: NSMakePoint(frame.minX + 341.69, frame.maxY - 408.59), controlPoint2: NSMakePoint(frame.minX + 350.74, frame.maxY - 405.75))
        bezierPath.curve(to: NSMakePoint(frame.minX + 378.32, frame.maxY - 413.18), controlPoint1: NSMakePoint(frame.minX + 364.7, frame.maxY - 405.75), controlPoint2: NSMakePoint(frame.minX + 373.75, frame.maxY - 408.59))
        bezierPath.curve(to: NSMakePoint(frame.minX + 385.72, frame.maxY - 433.87), controlPoint1: NSMakePoint(frame.minX + 382.89, frame.maxY - 417.78), controlPoint2: NSMakePoint(frame.minX + 385.72, frame.maxY - 426.86))
        bezierPath.close()
        fillColor2.setFill()
        bezierPath.fill()

        //// Bezier 2 Drawing
        let bezier2Path = NSBezierPath()
        bezier2Path.move(to: NSMakePoint(frame.minX + 310.19, frame.maxY - 428.96))
        bezier2Path.curve(to: NSMakePoint(frame.minX + 303.53, frame.maxY - 448.54), controlPoint1: NSMakePoint(frame.minX + 310.19, frame.maxY - 435.27), controlPoint2: NSMakePoint(frame.minX + 307.64, frame.maxY - 444.41))
        bezier2Path.curve(to: NSMakePoint(frame.minX + 284.03, frame.maxY - 455.23), controlPoint1: NSMakePoint(frame.minX + 299.41, frame.maxY - 452.68), controlPoint2: NSMakePoint(frame.minX + 290.31, frame.maxY - 455.23))
        bezier2Path.curve(to: NSMakePoint(frame.minX + 264.54, frame.maxY - 448.54), controlPoint1: NSMakePoint(frame.minX + 277.75, frame.maxY - 455.23), controlPoint2: NSMakePoint(frame.minX + 268.65, frame.maxY - 452.68))
        bezier2Path.curve(to: NSMakePoint(frame.minX + 257.87, frame.maxY - 428.96), controlPoint1: NSMakePoint(frame.minX + 260.42, frame.maxY - 444.41), controlPoint2: NSMakePoint(frame.minX + 257.87, frame.maxY - 435.27))
        bezier2Path.curve(to: NSMakePoint(frame.minX + 264.54, frame.maxY - 409.38), controlPoint1: NSMakePoint(frame.minX + 257.87, frame.maxY - 422.65), controlPoint2: NSMakePoint(frame.minX + 260.42, frame.maxY - 413.51))
        bezier2Path.curve(to: NSMakePoint(frame.minX + 284.03, frame.maxY - 402.69), controlPoint1: NSMakePoint(frame.minX + 268.65, frame.maxY - 405.25), controlPoint2: NSMakePoint(frame.minX + 277.75, frame.maxY - 402.69))
        bezier2Path.curve(to: NSMakePoint(frame.minX + 303.53, frame.maxY - 409.38), controlPoint1: NSMakePoint(frame.minX + 290.31, frame.maxY - 402.69), controlPoint2: NSMakePoint(frame.minX + 299.41, frame.maxY - 405.24))
        bezier2Path.curve(to: NSMakePoint(frame.minX + 310.19, frame.maxY - 428.96), controlPoint1: NSMakePoint(frame.minX + 307.64, frame.maxY - 413.51), controlPoint2: NSMakePoint(frame.minX + 310.19, frame.maxY - 422.65))
        bezier2Path.close()
        fillColor2.setFill()
        bezier2Path.fill()

        //// Bezier 3 Drawing
        let bezier3Path = NSBezierPath()
        bezier3Path.move(to: NSMakePoint(frame.minX + 244.42, frame.maxY - 397.32))
        bezier3Path.curve(to: NSMakePoint(frame.minX + 238.5, frame.maxY - 415.8), controlPoint1: NSMakePoint(frame.minX + 244.42, frame.maxY - 402.93), controlPoint2: NSMakePoint(frame.minX + 242.16, frame.maxY - 412.12))
        bezier3Path.curve(to: NSMakePoint(frame.minX + 220.11, frame.maxY - 421.75), controlPoint1: NSMakePoint(frame.minX + 234.84, frame.maxY - 419.47), controlPoint2: NSMakePoint(frame.minX + 225.69, frame.maxY - 421.75))
        bezier3Path.curve(to: NSMakePoint(frame.minX + 201.72, frame.maxY - 415.8), controlPoint1: NSMakePoint(frame.minX + 214.52, frame.maxY - 421.75), controlPoint2: NSMakePoint(frame.minX + 205.38, frame.maxY - 419.47))
        bezier3Path.curve(to: NSMakePoint(frame.minX + 195.8, frame.maxY - 397.32), controlPoint1: NSMakePoint(frame.minX + 198.06, frame.maxY - 412.12), controlPoint2: NSMakePoint(frame.minX + 195.8, frame.maxY - 402.93))
        bezier3Path.curve(to: NSMakePoint(frame.minX + 201.72, frame.maxY - 378.86), controlPoint1: NSMakePoint(frame.minX + 195.8, frame.maxY - 391.72), controlPoint2: NSMakePoint(frame.minX + 198.06, frame.maxY - 382.53))
        bezier3Path.curve(to: NSMakePoint(frame.minX + 220.11, frame.maxY - 372.91), controlPoint1: NSMakePoint(frame.minX + 205.38, frame.maxY - 375.18), controlPoint2: NSMakePoint(frame.minX + 214.52, frame.maxY - 372.91))
        bezier3Path.curve(to: NSMakePoint(frame.minX + 238.5, frame.maxY - 378.86), controlPoint1: NSMakePoint(frame.minX + 225.69, frame.maxY - 372.91), controlPoint2: NSMakePoint(frame.minX + 234.84, frame.maxY - 375.18))
        bezier3Path.curve(to: NSMakePoint(frame.minX + 244.42, frame.maxY - 397.32), controlPoint1: NSMakePoint(frame.minX + 242.16, frame.maxY - 382.53), controlPoint2: NSMakePoint(frame.minX + 244.42, frame.maxY - 391.72))
        bezier3Path.close()
        fillColor2.setFill()
        bezier3Path.fill()

        //// Bezier 4 Drawing
        let bezier4Path = NSBezierPath()
        bezier4Path.move(to: NSMakePoint(frame.minX + 198.18, frame.maxY - 343.37))
        bezier4Path.curve(to: NSMakePoint(frame.minX + 193, frame.maxY - 360.73), controlPoint1: NSMakePoint(frame.minX + 198.18, frame.maxY - 348.28), controlPoint2: NSMakePoint(frame.minX + 196.2, frame.maxY - 357.51))
        bezier4Path.curve(to: NSMakePoint(frame.minX + 175.71, frame.maxY - 365.94), controlPoint1: NSMakePoint(frame.minX + 189.8, frame.maxY - 363.95), controlPoint2: NSMakePoint(frame.minX + 180.6, frame.maxY - 365.94))
        bezier4Path.curve(to: NSMakePoint(frame.minX + 158.43, frame.maxY - 360.73), controlPoint1: NSMakePoint(frame.minX + 170.83, frame.maxY - 365.94), controlPoint2: NSMakePoint(frame.minX + 161.63, frame.maxY - 363.95))
        bezier4Path.curve(to: NSMakePoint(frame.minX + 153.25, frame.maxY - 343.37), controlPoint1: NSMakePoint(frame.minX + 155.23, frame.maxY - 357.51), controlPoint2: NSMakePoint(frame.minX + 153.25, frame.maxY - 348.28))
        bezier4Path.curve(to: NSMakePoint(frame.minX + 158.43, frame.maxY - 326.01), controlPoint1: NSMakePoint(frame.minX + 153.25, frame.maxY - 338.46), controlPoint2: NSMakePoint(frame.minX + 155.23, frame.maxY - 329.22))
        bezier4Path.curve(to: NSMakePoint(frame.minX + 175.71, frame.maxY - 320.8), controlPoint1: NSMakePoint(frame.minX + 161.63, frame.maxY - 322.79), controlPoint2: NSMakePoint(frame.minX + 170.83, frame.maxY - 320.8))
        bezier4Path.curve(to: NSMakePoint(frame.minX + 193, frame.maxY - 326.01), controlPoint1: NSMakePoint(frame.minX + 180.6, frame.maxY - 320.8), controlPoint2: NSMakePoint(frame.minX + 189.8, frame.maxY - 322.79))
        bezier4Path.curve(to: NSMakePoint(frame.minX + 198.18, frame.maxY - 343.37), controlPoint1: NSMakePoint(frame.minX + 196.2, frame.maxY - 329.22), controlPoint2: NSMakePoint(frame.minX + 198.18, frame.maxY - 338.46))
        bezier4Path.close()
        fillColor2.setFill()
        bezier4Path.fill()

        //// Bezier 5 Drawing
        let bezier5Path = NSBezierPath()
        bezier5Path.move(to: NSMakePoint(frame.minX + 189.24, frame.maxY - 279.52))
        bezier5Path.curve(to: NSMakePoint(frame.minX + 184.8, frame.maxY - 295.77), controlPoint1: NSMakePoint(frame.minX + 189.24, frame.maxY - 283.72), controlPoint2: NSMakePoint(frame.minX + 187.54, frame.maxY - 293.01))
        bezier5Path.curve(to: NSMakePoint(frame.minX + 168.62, frame.maxY - 300.23), controlPoint1: NSMakePoint(frame.minX + 182.06, frame.maxY - 298.52), controlPoint2: NSMakePoint(frame.minX + 172.81, frame.maxY - 300.23))
        bezier5Path.curve(to: NSMakePoint(frame.minX + 152.44, frame.maxY - 295.77), controlPoint1: NSMakePoint(frame.minX + 164.43, frame.maxY - 300.23), controlPoint2: NSMakePoint(frame.minX + 155.19, frame.maxY - 298.52))
        bezier5Path.curve(to: NSMakePoint(frame.minX + 148, frame.maxY - 279.52), controlPoint1: NSMakePoint(frame.minX + 149.7, frame.maxY - 293.01), controlPoint2: NSMakePoint(frame.minX + 148, frame.maxY - 283.72))
        bezier5Path.curve(to: NSMakePoint(frame.minX + 152.44, frame.maxY - 263.27), controlPoint1: NSMakePoint(frame.minX + 148, frame.maxY - 275.31), controlPoint2: NSMakePoint(frame.minX + 149.7, frame.maxY - 266.02))
        bezier5Path.curve(to: NSMakePoint(frame.minX + 168.62, frame.maxY - 258.8), controlPoint1: NSMakePoint(frame.minX + 155.19, frame.maxY - 260.51), controlPoint2: NSMakePoint(frame.minX + 164.43, frame.maxY - 258.8))
        bezier5Path.curve(to: NSMakePoint(frame.minX + 184.8, frame.maxY - 263.27), controlPoint1: NSMakePoint(frame.minX + 172.81, frame.maxY - 258.8), controlPoint2: NSMakePoint(frame.minX + 182.06, frame.maxY - 260.51))
        bezier5Path.curve(to: NSMakePoint(frame.minX + 189.24, frame.maxY - 279.52), controlPoint1: NSMakePoint(frame.minX + 187.54, frame.maxY - 266.02), controlPoint2: NSMakePoint(frame.minX + 189.24, frame.maxY - 275.31))
        bezier5Path.close()
        fillColor2.setFill()
        bezier5Path.fill()

        //// Bezier 6 Drawing
        let bezier6Path = NSBezierPath()
        bezier6Path.move(to: NSMakePoint(frame.minX + 206.82, frame.maxY - 222.26))
        bezier6Path.curve(to: NSMakePoint(frame.minX + 203.12, frame.maxY - 237.41), controlPoint1: NSMakePoint(frame.minX + 206.82, frame.maxY - 225.77), controlPoint2: NSMakePoint(frame.minX + 205.41, frame.maxY - 235.11))
        bezier6Path.curve(to: NSMakePoint(frame.minX + 188.05, frame.maxY - 241.12), controlPoint1: NSMakePoint(frame.minX + 200.84, frame.maxY - 239.7), controlPoint2: NSMakePoint(frame.minX + 191.54, frame.maxY - 241.12))
        bezier6Path.curve(to: NSMakePoint(frame.minX + 172.97, frame.maxY - 237.41), controlPoint1: NSMakePoint(frame.minX + 184.56, frame.maxY - 241.12), controlPoint2: NSMakePoint(frame.minX + 175.26, frame.maxY - 239.7))
        bezier6Path.curve(to: NSMakePoint(frame.minX + 169.27, frame.maxY - 222.26), controlPoint1: NSMakePoint(frame.minX + 170.69, frame.maxY - 235.11), controlPoint2: NSMakePoint(frame.minX + 169.27, frame.maxY - 225.77))
        bezier6Path.curve(to: NSMakePoint(frame.minX + 172.97, frame.maxY - 207.12), controlPoint1: NSMakePoint(frame.minX + 169.27, frame.maxY - 218.76), controlPoint2: NSMakePoint(frame.minX + 170.69, frame.maxY - 209.42))
        bezier6Path.curve(to: NSMakePoint(frame.minX + 188.05, frame.maxY - 203.41), controlPoint1: NSMakePoint(frame.minX + 175.26, frame.maxY - 204.83), controlPoint2: NSMakePoint(frame.minX + 184.56, frame.maxY - 203.41))
        bezier6Path.curve(to: NSMakePoint(frame.minX + 203.12, frame.maxY - 207.12), controlPoint1: NSMakePoint(frame.minX + 191.54, frame.maxY - 203.41), controlPoint2: NSMakePoint(frame.minX + 200.84, frame.maxY - 204.83))
        bezier6Path.curve(to: NSMakePoint(frame.minX + 206.82, frame.maxY - 222.26), controlPoint1: NSMakePoint(frame.minX + 205.41, frame.maxY - 209.42), controlPoint2: NSMakePoint(frame.minX + 206.82, frame.maxY - 218.76))
        bezier6Path.close()
        fillColor2.setFill()
        bezier6Path.fill()

        //// Bezier 7 Drawing
        let bezier7Path = NSBezierPath()
        bezier7Path.move(to: NSMakePoint(frame.minX + 247.85, frame.maxY - 182.09))
        bezier7Path.curve(to: NSMakePoint(frame.minX + 244.89, frame.maxY - 196.12), controlPoint1: NSMakePoint(frame.minX + 247.85, frame.maxY - 184.9), controlPoint2: NSMakePoint(frame.minX + 246.72, frame.maxY - 194.29))
        bezier7Path.curve(to: NSMakePoint(frame.minX + 230.92, frame.maxY - 199.1), controlPoint1: NSMakePoint(frame.minX + 243.06, frame.maxY - 197.96), controlPoint2: NSMakePoint(frame.minX + 233.72, frame.maxY - 199.1))
        bezier7Path.curve(to: NSMakePoint(frame.minX + 216.95, frame.maxY - 196.12), controlPoint1: NSMakePoint(frame.minX + 228.13, frame.maxY - 199.1), controlPoint2: NSMakePoint(frame.minX + 218.78, frame.maxY - 197.96))
        bezier7Path.curve(to: NSMakePoint(frame.minX + 213.99, frame.maxY - 182.09), controlPoint1: NSMakePoint(frame.minX + 215.12, frame.maxY - 194.29), controlPoint2: NSMakePoint(frame.minX + 213.99, frame.maxY - 184.9))
        bezier7Path.curve(to: NSMakePoint(frame.minX + 216.95, frame.maxY - 168.06), controlPoint1: NSMakePoint(frame.minX + 213.99, frame.maxY - 179.29), controlPoint2: NSMakePoint(frame.minX + 215.12, frame.maxY - 169.9))
        bezier7Path.curve(to: NSMakePoint(frame.minX + 230.92, frame.maxY - 165.09), controlPoint1: NSMakePoint(frame.minX + 218.78, frame.maxY - 166.22), controlPoint2: NSMakePoint(frame.minX + 228.13, frame.maxY - 165.09))
        bezier7Path.curve(to: NSMakePoint(frame.minX + 244.89, frame.maxY - 168.06), controlPoint1: NSMakePoint(frame.minX + 233.72, frame.maxY - 165.09), controlPoint2: NSMakePoint(frame.minX + 243.06, frame.maxY - 166.22))
        bezier7Path.curve(to: NSMakePoint(frame.minX + 247.85, frame.maxY - 182.09), controlPoint1: NSMakePoint(frame.minX + 246.72, frame.maxY - 169.9), controlPoint2: NSMakePoint(frame.minX + 247.85, frame.maxY - 179.29))
        bezier7Path.close()
        fillColor2.setFill()
        bezier7Path.fill()

        //// Bezier 8 Drawing
        let bezier8Path = NSBezierPath()
        bezier8Path.move(to: NSMakePoint(frame.minX + 297.42, frame.maxY - 169.78))
        bezier8Path.curve(to: NSMakePoint(frame.minX + 295.2, frame.maxY - 182.71), controlPoint1: NSMakePoint(frame.minX + 297.42, frame.maxY - 171.89), controlPoint2: NSMakePoint(frame.minX + 296.57, frame.maxY - 181.33))
        bezier8Path.curve(to: NSMakePoint(frame.minX + 282.33, frame.maxY - 184.94), controlPoint1: NSMakePoint(frame.minX + 293.82, frame.maxY - 184.08), controlPoint2: NSMakePoint(frame.minX + 284.42, frame.maxY - 184.94))
        bezier8Path.curve(to: NSMakePoint(frame.minX + 269.47, frame.maxY - 182.71), controlPoint1: NSMakePoint(frame.minX + 280.24, frame.maxY - 184.94), controlPoint2: NSMakePoint(frame.minX + 270.84, frame.maxY - 184.08))
        bezier8Path.curve(to: NSMakePoint(frame.minX + 267.25, frame.maxY - 169.78), controlPoint1: NSMakePoint(frame.minX + 268.09, frame.maxY - 181.33), controlPoint2: NSMakePoint(frame.minX + 267.25, frame.maxY - 171.89))
        bezier8Path.curve(to: NSMakePoint(frame.minX + 269.47, frame.maxY - 156.86), controlPoint1: NSMakePoint(frame.minX + 267.25, frame.maxY - 167.68), controlPoint2: NSMakePoint(frame.minX + 268.09, frame.maxY - 158.24))
        bezier8Path.curve(to: NSMakePoint(frame.minX + 282.33, frame.maxY - 154.63), controlPoint1: NSMakePoint(frame.minX + 270.84, frame.maxY - 155.48), controlPoint2: NSMakePoint(frame.minX + 280.24, frame.maxY - 154.63))
        bezier8Path.curve(to: NSMakePoint(frame.minX + 295.2, frame.maxY - 156.86), controlPoint1: NSMakePoint(frame.minX + 284.42, frame.maxY - 154.63), controlPoint2: NSMakePoint(frame.minX + 293.82, frame.maxY - 155.48))
        bezier8Path.curve(to: NSMakePoint(frame.minX + 297.42, frame.maxY - 169.78), controlPoint1: NSMakePoint(frame.minX + 296.57, frame.maxY - 158.24), controlPoint2: NSMakePoint(frame.minX + 297.42, frame.maxY - 167.68))
        bezier8Path.close()
        fillColor2.setFill()
        bezier8Path.fill()

        //// Bezier 9 Drawing
        let bezier9Path = NSBezierPath()
        bezier9Path.move(to: NSMakePoint(frame.minX + 344.59, frame.maxY - 182.09))
        bezier9Path.curve(to: NSMakePoint(frame.minX + 343.11, frame.maxY - 193.9), controlPoint1: NSMakePoint(frame.minX + 344.59, frame.maxY - 183.49), controlPoint2: NSMakePoint(frame.minX + 344.02, frame.maxY - 192.99))
        bezier9Path.curve(to: NSMakePoint(frame.minX + 331.35, frame.maxY - 195.39), controlPoint1: NSMakePoint(frame.minX + 342.19, frame.maxY - 194.82), controlPoint2: NSMakePoint(frame.minX + 332.74, frame.maxY - 195.39))
        bezier9Path.curve(to: NSMakePoint(frame.minX + 319.59, frame.maxY - 193.9), controlPoint1: NSMakePoint(frame.minX + 329.95, frame.maxY - 195.39), controlPoint2: NSMakePoint(frame.minX + 320.5, frame.maxY - 194.82))
        bezier9Path.curve(to: NSMakePoint(frame.minX + 318.11, frame.maxY - 182.09), controlPoint1: NSMakePoint(frame.minX + 318.67, frame.maxY - 192.99), controlPoint2: NSMakePoint(frame.minX + 318.11, frame.maxY - 183.49))
        bezier9Path.curve(to: NSMakePoint(frame.minX + 319.59, frame.maxY - 170.28), controlPoint1: NSMakePoint(frame.minX + 318.11, frame.maxY - 180.69), controlPoint2: NSMakePoint(frame.minX + 318.67, frame.maxY - 171.2))
        bezier9Path.curve(to: NSMakePoint(frame.minX + 331.35, frame.maxY - 168.79), controlPoint1: NSMakePoint(frame.minX + 320.5, frame.maxY - 169.36), controlPoint2: NSMakePoint(frame.minX + 329.95, frame.maxY - 168.79))
        bezier9Path.curve(to: NSMakePoint(frame.minX + 343.11, frame.maxY - 170.28), controlPoint1: NSMakePoint(frame.minX + 332.74, frame.maxY - 168.79), controlPoint2: NSMakePoint(frame.minX + 342.19, frame.maxY - 169.36))
        bezier9Path.curve(to: NSMakePoint(frame.minX + 344.59, frame.maxY - 182.09), controlPoint1: NSMakePoint(frame.minX + 344.02, frame.maxY - 171.2), controlPoint2: NSMakePoint(frame.minX + 344.59, frame.maxY - 180.69))
        bezier9Path.close()
        fillColor2.setFill()
        bezier9Path.fill()

        //// Bezier 10 Drawing
        let bezier10Path = NSBezierPath()
        bezier10Path.move(to: NSMakePoint(frame.minX + 377.6, frame.maxY - 213.42))
        bezier10Path.curve(to: NSMakePoint(frame.minX + 376.86, frame.maxY - 224.12), controlPoint1: NSMakePoint(frame.minX + 377.6, frame.maxY - 214.12), controlPoint2: NSMakePoint(frame.minX + 377.31, frame.maxY - 223.66))
        bezier10Path.curve(to: NSMakePoint(frame.minX + 366.2, frame.maxY - 224.86), controlPoint1: NSMakePoint(frame.minX + 376.4, frame.maxY - 224.58), controlPoint2: NSMakePoint(frame.minX + 366.9, frame.maxY - 224.86))
        bezier10Path.curve(to: NSMakePoint(frame.minX + 355.55, frame.maxY - 224.12), controlPoint1: NSMakePoint(frame.minX + 365.5, frame.maxY - 224.86), controlPoint2: NSMakePoint(frame.minX + 356, frame.maxY - 224.58))
        bezier10Path.curve(to: NSMakePoint(frame.minX + 354.8, frame.maxY - 213.42), controlPoint1: NSMakePoint(frame.minX + 355.09, frame.maxY - 223.66), controlPoint2: NSMakePoint(frame.minX + 354.8, frame.maxY - 214.12))
        bezier10Path.curve(to: NSMakePoint(frame.minX + 355.55, frame.maxY - 202.72), controlPoint1: NSMakePoint(frame.minX + 354.8, frame.maxY - 212.72), controlPoint2: NSMakePoint(frame.minX + 355.09, frame.maxY - 203.18))
        bezier10Path.curve(to: NSMakePoint(frame.minX + 366.2, frame.maxY - 201.97), controlPoint1: NSMakePoint(frame.minX + 356, frame.maxY - 202.26), controlPoint2: NSMakePoint(frame.minX + 365.5, frame.maxY - 201.97))
        bezier10Path.curve(to: NSMakePoint(frame.minX + 376.86, frame.maxY - 202.72), controlPoint1: NSMakePoint(frame.minX + 366.9, frame.maxY - 201.97), controlPoint2: NSMakePoint(frame.minX + 376.4, frame.maxY - 202.26))
        bezier10Path.curve(to: NSMakePoint(frame.minX + 377.6, frame.maxY - 213.42), controlPoint1: NSMakePoint(frame.minX + 377.31, frame.maxY - 203.18), controlPoint2: NSMakePoint(frame.minX + 377.6, frame.maxY - 212.72))
        bezier10Path.close()
        fillColor2.setFill()
        bezier10Path.fill()

        //// Rectangle 4 Drawing
        let rectangle4Path = NSBezierPath(rect: NSMakeRect(frame.minX + 372.25, frame.minY + frame.height - 264.75, 17.9, 19.9))
        fillColor2.setFill()
        rectangle4Path.fill()

        //// Oval Drawing
        let ovalPath = NSBezierPath(ovalIn: NSMakeRect(frame.minX + 402.15, frame.minY + frame.height - 443.8, 63.4, 63.4))
        fillColor2.setFill()
        ovalPath.fill()
    }

}

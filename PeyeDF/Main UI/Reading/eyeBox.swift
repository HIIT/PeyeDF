//
// Copyright (c) 2018 University of Helsinki, Aalto University
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

/// The eyebox is a simple view that shows the user position as detected by the eye tracker, so participants 
/// can adjust their own position. Uses PeyeConstants.eyePositionNotification to track eye position.
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
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        registerNotification()
    }
    
    deinit {
        unregisterNotification()
    }
    
    func registerNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(newDataReceived(_:)), name: PeyeConstants.eyePositionNotification, object: nil)
    }
    
    func unregisterNotification() {
        NotificationCenter.default.removeObserver(self, name: PeyeConstants.eyePositionNotification, object: nil)
    }
    
    /// Notification callback
    @objc func newDataReceived(_ notification: Notification) {
        let userInfo = (notification as NSNotification).userInfo!
        DispatchQueue.main.async {
            self.dist = CGFloat(userInfo["zpos"] as! Double)
            self.xdelta = CGFloat(userInfo["xpos"] as! Double)
            self.ydelta = CGFloat(userInfo["ypos"] as! Double)
            self.needsDisplay = true
        }
    }

    /// Draws itself depending on last received position
    override func draw(_ dirtyRect: NSRect) {
        
        // circle max size when dist == maxdist has the radius of half the side size of inner box
        
        super.draw(dirtyRect)
        
        let innerPathSize: CGFloat = frame.width - boxMargin * 2
        let innerPath = NSBezierPath(rect: NSRect(origin: NSPoint(x: boxMargin, y: boxMargin), size: NSSize(width: innerPathSize, height: innerPathSize)))
        
        innerPath.lineWidth = 1
        innerPath.lineJoinStyle = .round
        
        // only draw circle if all positions are != 0
        
        if self.dist != 0 && self.xdelta != 0  && self.ydelta != 0 {
            
            // 1 is mapped to circleMinSize
            // maxProp is mapped to innerpathsize
            let circleSize = translate(dist, leftMin: maxDist, leftMax: minDist, rightMin: circleMinSize, rightMax: innerPathSize / 2)
            
            if dist > minDist {
                let circX = getDDelta(xdelta, maxDelta: maxXdelta, maxPos: innerPathSize / 2)
                let circY = getDDelta(ydelta, maxDelta: maxYdelta, maxPos: innerPathSize / 2)
                let centerPoint: CGFloat = frame.width / 2 // center point in the box x and y are the same
                let circleOrigin = NSPoint(x: centerPoint + circX, y: centerPoint + circY)
                let origin = NSPoint(x: circleOrigin.x - circleSize / 2, y: circleOrigin.y - circleSize / 2)
                let circlePath = NSBezierPath(ovalIn: NSRect(origin: origin, size: NSSize(width: circleSize, height: circleSize)))
                circlePath.stroke()
            }
            
        }
        
        marginColour.set()
        innerPath.stroke()
            
    }
    
    /// Translates a raw position (x and/or y) into box position
    fileprivate func getDDelta(_ pos: CGFloat, maxDelta: CGFloat, maxPos: CGFloat) -> CGFloat {
        let isnegative = pos < 0
        let pos = abs(pos)
        let retVal = translate(pos, leftMin: 0, leftMax: maxDelta, rightMin: 0, rightMax: maxPos)
        return isnegative ? -retVal : retVal
    }
    
}


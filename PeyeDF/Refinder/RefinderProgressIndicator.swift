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

import Cocoa

class RefinderProgressIndicator: NSView {
    
    /// Corner radius for display (higher values might crash)
    let kCr: CGFloat = 1.5
    
    override var wantsUpdateLayer: Bool { get {
        return true
    } }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        completeInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        completeInit()
    }
    
    /// Convenience function to complete initialization
    func completeInit() {
        self.wantsLayer = true
        self.layer?.addSublayer(frontLayer)
        self.layer?.addSublayer(backLayer)
        self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawPolicy.DuringViewResize
    }
    
    /// Drawn "outside" to show borders
    let backLayer: CAShapeLayer = {
        let shape = CAShapeLayer()
        shape.lineWidth = 0.5
        shape.fillColor = nil
        return shape
    }()
    
    /// Drawn "inside" with a colour
    let frontLayer = CAShapeLayer()
    
    /// Progress in a proportion
    var progress = 0.0
    
    /// Class represented by this bar
    var readingC = ReadingClass.Unset

    func setProgress(newProgress: Double, forClass: ReadingClass) {
        self.progress = newProgress
        self.readingC = forClass
        
        // set own colours depending on class
        var colour = NSColor.whiteColor()
        if readingC == ReadingClass.Read {
            colour = PeyeConstants.annotationColourRead.colorWithAlphaComponent(1)
        } else if readingC == ReadingClass.Interesting {
            colour = PeyeConstants.annotationColourInteresting.colorWithAlphaComponent(1)
        } else if readingC == ReadingClass.Critical {
            colour = PeyeConstants.annotationColourCritical.colorWithAlphaComponent(1)
        }
        
        backLayer.strokeColor = colour.CGColor
        frontLayer.fillColor = colour.CGColor
    }
    
    /// Overriden to readjust its own size
    override func updateLayer() {
        super.updateLayer()
        
        // use rounded rect and subtract a little to fit corners in view
        var rect = self.bounds.addTo(-1.5)
        
        let backPath = CGPathCreateWithRoundedRect(rect, kCr, kCr, nil)
        backLayer.path = backPath
        
        // hide front layer if width is less than twice the corner (otherwise would crash)
        rect.size.width *= CGFloat(progress)
        if rect.size.width > kCr * 2 {
            let frontPath = CGPathCreateWithRoundedRect(rect, kCr, kCr, nil)
            frontLayer.path = frontPath
            frontLayer.hidden = false
        } else {
            frontLayer.hidden = true
        }
        
    }
    
}

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
        self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawPolicy.duringViewResize
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
    var readingC = ReadingClass.unset

    func setProgress(_ newProgress: Double?, forClass: ReadingClass) {
        if let progress = newProgress, progress > 0 {
            if progress < 1 {
                self.progress = progress
            } else {
                self.progress = 1
            }
        }
        self.readingC = forClass
        
        // set own colours depending on class
        var colour = NSColor.white
        if readingC == ReadingClass.low {
            colour = PeyeConstants.annotationColourRead.withAlphaComponent(1)
        } else if readingC == ReadingClass.medium {
            colour = PeyeConstants.annotationColourInteresting.withAlphaComponent(1)
        } else if readingC == ReadingClass.high {
            colour = PeyeConstants.annotationColourCritical.withAlphaComponent(1)
        }
        
        backLayer.strokeColor = colour.cgColor
        frontLayer.fillColor = colour.cgColor
        self.needsDisplay = true
    }
    
    /// Overriden to readjust its own size
    override func updateLayer() {
        super.updateLayer()
        
        // use rounded rect and subtract a little to fit corners in view
        var rect = self.bounds.addTo(-1.5)
        
        let backPath = CGPath(roundedRect: rect, cornerWidth: kCr, cornerHeight: kCr, transform: nil)
        backLayer.path = backPath
        
        // hide front layer if width is less than twice the corner (otherwise would crash)
        rect.size.width *= CGFloat(progress)
        if rect.size.width > kCr * 2 {
            let frontPath = CGPath(roundedRect: rect, cornerWidth: kCr, cornerHeight: kCr, transform: nil)
            frontLayer.path = frontPath
            frontLayer.isHidden = false
        } else {
            frontLayer.isHidden = true
        }
        
    }
    
}

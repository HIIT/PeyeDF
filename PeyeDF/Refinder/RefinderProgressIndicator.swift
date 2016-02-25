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

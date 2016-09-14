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

extension NSRect: Comparable { } // Make NSRects comparable using their public == and < functions

/// Two rects are equal if all their properties are equal
public func == (lhs: NSRect, rhs: NSRect) -> Bool {
    return lhs.origin.x == rhs.origin.x &&
        lhs.origin.y == rhs.origin.y &&
        lhs.size.height == rhs.size.height &&
        lhs.size.width == rhs.size.width
}

/// Check if the left hand side rect comes before the right hand side rect.
/// Most important is x position. The rect with a lower x (left most) comes
/// before the rect with a higher x. If the x are within a specified range
/// checked using withinRange(_,_,constant) then rects with higher y
/// come before rects with lower y.
public func < (lhs: NSRect, rhs: NSRect) -> Bool {
    let constant: CGFloat = PeyeConstants.rectHorizontalTolerance
    if withinRange(lhs.origin.x, rhs: rhs.origin.x, range: constant) {
        return lhs.origin.y > rhs.origin.y
    } else {
        return lhs.origin.x < rhs.origin.x
    }
}

extension NSRect {
    
    /// Creates a rect from a string specifying 'x,y,w,h'
    /// - returns: nil if conversion failed
    init?(string: String) {
        if let spl = string.split(",") , spl.count == 4 {
            let nf = NumberFormatter()
            nf.localizesFormat = false  // to be locale-independent
            if let x = nf.number(from: spl[0]) as? CGFloat,
              let y = nf.number(from: spl[1]) as? CGFloat,
              let w = nf.number(from: spl[2]) as? CGFloat,
              let h = nf.number(from: spl[3]) as? CGFloat {
                self.origin = NSPoint(x: x, y: y)
                self.size = NSSize(width: w, height: h)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    /// Subtracts another rectangle **from** this rectangle. That is,
    /// returns this rectangle as a (possibly disjoint) array. Only one element
    /// is returned in the array if the lhs was not entirely enclosed by this element.
    /// Returns a array with the original rectangle if the two don't intersect (or are away
    /// a certain tolerance (PeyeConstants.rectHorizontalTolerance) on the x axis.
    /// An empty array if the subtrahend completely encloses this rect.
    ///
    /// - parameter rhs: The rectangle that will be subtracted **from** this rectangle (subtrahend)
    /// - returns: An array of rectangles, the result of the operation
    func subtractRect(_ rhs: NSRect) -> [NSRect] {
        let constant: CGFloat = PeyeConstants.rectHorizontalTolerance
        var ary = [NSRect]()
        // if the other rectangle encloses this (taking into account some tolerance)
        // return an empty array
        if NSContainsRect(rhs, self.insetBy(dx: PeyeConstants.rectHorizontalTolerance, dy: PeyeConstants.rectVerticalTolerance)) {
            return ary
        }
        if withinRange(self.origin.x, rhs: rhs.origin.x, range: constant) {
            if NSIntersectsRect(self, rhs) {
                var slice = NSRect()
                var remainder = NSRect()
                if self.minY < rhs.minY {
                    // this rectangle extends below the other
                    // slce the bottom from below
                    let sliceFromBottom = rhs.minY - self.minY
                    NSDivideRect(self, &slice, &remainder, sliceFromBottom, NSRectEdge.minY)
                    if slice.size.height > PeyeConstants.minRectHeight {
                        ary.append(slice)
                    }
                }
                if self.maxY > rhs.maxY {
                    // this rectangle extends above the other
                    // slice the top from above
                    let sliceFromTop = self.maxY - rhs.maxY
                    NSDivideRect(self, &slice, &remainder, sliceFromTop, NSRectEdge.maxY)
                    if slice.size.height > PeyeConstants.minRectHeight {
                        ary.append(slice)
                    }
                }
                return ary
            }
        }
        ary.append(self)
        return ary
    }
    
    /// Scale this rect by a given factor (by multiplication) and return a new rect.
    func scale(_ scale: CGFloat) -> NSRect {
        let newWidth = self.size.width * scale
        let newHeight = self.size.height * scale
        let widthDiff = newWidth - self.size.width
        let heightDiff = newHeight - self.size.height
        
        let newx = self.origin.x - widthDiff / 2
        let newy = self.origin.y - heightDiff / 2
        
        return NSMakeRect(newx, newy, newWidth, newHeight);
    }
    
    /// Scale this rect by a given factor (by addition) and return a new rect.
    /// Returns rounded values (used for "pixel-perfect" display).
    func addTo(_ scale: CGFloat) -> NSRect {
        var newOrigin = NSPoint()
    
        let maxX = CGFloat(ceilf(Float(self.origin.x + self.size.width))) + scale
        let maxY = CGFloat(ceilf(Float(self.origin.y + self.size.height))) + scale
        newOrigin.x = CGFloat(floorf(Float(self.origin.x))) - scale
        newOrigin.y = CGFloat(floorf(Float(self.origin.y))) - scale
        
        return NSMakeRect(newOrigin.x, newOrigin.y, maxX - newOrigin.x, maxY - newOrigin.y);
    }
    
    /// Scale this rect by a given factor (by addition) and return a new rect.
    /// Returns an unrounded rect (used for documents).
    func outset(_ scale: CGFloat) -> NSRect {
        var newOrigin = NSPoint()
    
        let maxX = self.origin.x + self.size.width + scale / 2.0
        let maxY = self.origin.y + self.size.height + scale / 2.0
        newOrigin.x = self.origin.x - scale / 2.0
        newOrigin.y = self.origin.y - scale / 2.0
        
        return NSMakeRect(newOrigin.x, newOrigin.y, maxX - newOrigin.x, maxY - newOrigin.y);
    }
    
    /// Returns a new rectangle based on this one but with the origin offset
    /// by adding the given point to it.
    func offset(byPoint point: NSPoint) -> NSRect {
        var newOrigin = self.origin
        newOrigin.x += point.x
        newOrigin.y += point.y
        return NSRect(origin: newOrigin, size: self.size)
    }
    
    /// Returns true if this rect is "near" the other rect.
    /// Uses values optimised for PDF (page space) coordinates.
    func isNear(_ toRect: NSRect) -> Bool {
        // size of the narrower rect
        let maxXdiff = min(self.size.width, toRect.size.width)
        // minimum between distance of extremes (left / right alignment)
        let maxYdiff = min(self.size.height, toRect.size.height)
        
        let xDiff1 = abs(self.origin.x - toRect.origin.x)
        let xDiff2 = abs((self.origin.x + self.size.width) -
                         (toRect.origin.x + toRect.size.width))
        let xDiff = min(xDiff1, xDiff2)
        let yDiff1 = abs(self.origin.y - (toRect.origin.y + toRect.size.height))
        let yDiff2 = abs(self.origin.y + self.size.height - toRect.origin.y)
        let yDiff = min(yDiff1, yDiff2)
        return xDiff <= maxXdiff && yDiff <= maxYdiff
    }
    
    /// Returns true if this rect is "near" the other rect, vertically.
    /// (Their vertical distance is less than the minimum vertical size between the two).
    func isVerticallyNear(_ toRect: NSRect) -> Bool {
        // minimum between distance of extremes (left / right alignment)
        let maxYdiff = min(self.size.height, toRect.size.height) * 1.2
        
        let yDiff1 = abs(self.origin.y - (toRect.origin.y + toRect.size.height))
        let yDiff2 = abs(self.origin.y + self.size.height - toRect.origin.y)
        let yDiff = min(yDiff1, yDiff2)
        return yDiff <= maxYdiff
    }
    
    /// Returns true if the x coordinates of the two rects overlap.
    /// Returns true if either X edge of this rect is within the other rect edges.
    func horizontalOverlap(_ other: NSRect) -> Bool {
        return (self.minX >= other.minX && self.minX <= other.maxX) ||
               (self.maxX >= other.minX && self.maxX <= other.maxX) ||
               (other.minX >= self.minX && other.minX <= self.maxX) ||
               (other.maxX >= self.minX && other.maxX <= self.maxX)
    }
    
}

extension NSRect: Hashable {
    public var hashValue: Int { get {
        return size.hashValue ^ origin.hashValue
    } }
}

extension NSRect: CustomStringConvertible {
    
    /**
     Format: 'x,y,w,h'
     */
    public var description: String { get {
        return "\(self.origin.x),\(self.origin.y),\(self.size.width),\(self.size.height)"
    } }
}

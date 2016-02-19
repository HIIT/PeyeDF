//
//  NSRect+Extensions.swift
//  PeyeDF
//
//  Created by Marco Filetti on 19/02/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

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
    
    /// Subtracts another rectangle **from** this rectangle. That is,
    /// returns this rectangle as a (possibly disjoint) array. Only one element
    /// is returned in the array if the lhs was not entirely enclosed by this element.
    /// Returns a array with the original rectangle if the two don't intersect (or are away
    /// a certain tolerance (PeyeConstants.rectHorizontalTolerance) on the x axis.
    /// An empty array if the subtrahend completely encloses this rect.
    ///
    /// - parameter rhs: The rectangle that will be subtracted **from** this rectangle (subtrahend)
    /// - returns: An array of rectangles, the result of the operation
    func subtractRect(rhs: NSRect) -> [NSRect] {
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
                    NSDivideRect(self, &slice, &remainder, sliceFromBottom, NSRectEdge.MinY)
                    if slice.size.height > PeyeConstants.minRectHeight {
                        ary.append(slice)
                    }
                }
                if self.maxY > rhs.maxY {
                    // this rectangle extends above the other
                    // slice the top from above
                    let sliceFromTop = self.maxY - rhs.maxY
                    NSDivideRect(self, &slice, &remainder, sliceFromTop, NSRectEdge.MaxY)
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
    func scale(scale: CGFloat) -> NSRect {
        let newWidth = self.size.width * scale
        let newHeight = self.size.height * scale
        let widthDiff = newWidth - self.size.width
        let heightDiff = newHeight - self.size.height
        
        let newx = self.origin.x - widthDiff / 2
        let newy = self.origin.y - heightDiff / 2
        
        return NSMakeRect(newx, newy, newWidth, newHeight);
    }
    
    /// Scale this rect by a given factor (by addition) and return a new rect.
    func addTo(scale: CGFloat) -> NSRect {
        var newOrigin = NSPoint()
    
        let maxX = CGFloat(ceilf(Float(self.origin.x + self.size.width))) + scale
        let maxY = CGFloat(ceilf(Float(self.origin.y + self.size.height))) + scale
        newOrigin.x = CGFloat(floorf(Float(self.origin.x))) - scale
        newOrigin.y = CGFloat(floorf(Float(self.origin.y))) - scale
        
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
}
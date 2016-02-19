//
//  NS+Extensions.swift
//  PeyeDF
//
//  Created by Marco Filetti on 19/02/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation
import Cocoa

extension NSNumber {
    
    /// Make sure this number of not equal to infinity or nan
    func isValid() -> Bool {
        let posInf = NSNumber(double: 1.0/0.0)
        if self == posInf {
            return false
        }
        if self == NSDecimalNumber.notANumber() {
            return false
        }
        return true
    }
}

extension NSSize {
    
    /// Returns true if both height and width are within a specified reference
    /// size, within a tolerance (which is a fraction of the given size)
    func withinTolerance(reference: NSSize, tolerance: CGFloat) -> Bool {
        let maxWidth = reference.width + reference.width * tolerance
        let maxHeight = reference.height + reference.height * tolerance
        let minWidth = reference.width - reference.width * tolerance
        let minHeight = reference.height - reference.height * tolerance
        return self.height < maxHeight && self.height > minHeight &&
               self.width < maxWidth && self.width > minWidth
    }
    
    /// Returns true if both height and width are **smaller** than a specified reference
    /// size, within a tolerance (which is a fraction of the given size)
    func withinMaxTolerance(reference: NSSize, tolerance: CGFloat) -> Bool {
        let maxWidth = reference.width + reference.width * tolerance
        let maxHeight = reference.height + reference.height * tolerance
        return self.height < maxHeight &&
               self.width < maxWidth
    }
    
}

extension NSColor {
    
    /// Returns true if all the components of the colour (rgb and alpha) are the same as the other color,
    /// ignoring the color space
    ///
    /// - parameter lhs: The color to compare to
    /// - returns: True if they are "practically equal"
    func practicallyEqual(lhs: NSColor) -> Bool {
        var components1 = [CGFloat](count: 4, repeatedValue: -1.0)
        var components2 = [CGFloat](count: 4, repeatedValue: -2.0)
        self.getComponents(&components1)
        lhs.getComponents(&components2)
        return components1 == components2
    }
}


extension NSPoint {
    
    /// Returns a new point in a given rect's coordinate system. In other words,
    /// a poing for which the origin matches the given rectangle's origin
    func pointInRectCoords(theRect: NSRect) -> NSPoint {
        return NSPoint(x: self.x - theRect.origin.x, y: self.y - theRect.origin.y)
    }
}

// MARK: - Other functions

/// Finds i given the condition that ary[i-1] <= target and a[i] > target, using a binary search on
/// a sorted array. Assuming no items are repeated.
///
/// - parameter ary: The sorted array to search
/// - parameter target: The item to search for
/// - returns: The index which corresponds to the item coming immediately after target (or the count of the array if last item <= target), 0 if the beginning of the array > target.
func binaryGreaterOnSortedArray<T: Comparable>(ary: [T], target: T) -> Int {
    var left: Int = 1
    var right: Int = ary.count - 1
    
    if ary.last! <= target {
        return ary.count
    }
    
    if ary.first! > target {
        return 0
    }
    
    var mid: Int = -1
    
    while (left <= right) {
        mid = (left + right) / 2
        let previousitem = ary[mid - 1]
        let value = ary[mid]
        
        if (previousitem <= target && value > target) {
            return mid
        }
        
        if (value == target) {
            return mid + 1
        }
        
        if (value < target) {
            left = mid + 1
        }
        
        if (previousitem > target) {
            right = mid - 1
        }
    }
    
    fatalError("Loop terminated without finding a value")
}

/// Finds i given the condition that ary[i-1] < target and a[i] >= target, using a binary search on
/// a sorted array. Returns the first match.
///
/// - parameter ary: The sorted array to search
/// - parameter target: The item to search for
/// - returns: The index which corresponds to the first match, the count of the array if firstOperator(last item > target), 0 if first item < target).
func binaryGreaterOrEqOnSortedArray<T: Comparable>(ary: [T], target: T) -> Int {
    var left: Int = 1
    var right: Int = ary.count - 1
    
    if ary.last! < target {
        return ary.count
    }
    
    if ary.first! > target {
        return 0
    }
    
    var mid: Int = -1
    
    while (left <= right) {
        mid = (left + right) / 2
        let previousitem = ary[mid - 1]
        let value = ary[mid]
        
        if (previousitem < target && value >= target) {
            return mid
        }
        
        if (value == target) {
            if mid-1 > 0 && ary[mid-1] < target {
                return mid
            } else if previousitem == target {
                right = mid - 1
            }
        }
        
        if (value < target) {
            left = mid + 1
        }
        
        if (previousitem > target) {
            right = mid - 1
        }
    }
    
    fatalError("Loop terminated without finding a value")
}
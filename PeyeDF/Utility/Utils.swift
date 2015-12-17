//
//  Utils.swift
//  PeyeDF
//
//  Created by Marco Filetti on 30/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//
// Contains various functions and utilities not otherwise classified

import Foundation
import Cocoa

// MARK: - Extensions to standard types

extension NSDate {
    
    /// Number of ms since 1/1/1970. Read-only computed property.
    var unixTime: Int { get {
        return Int(round(self.timeIntervalSince1970 * 1000))
        }
    }
    
    
    /// Returns the current time in a short format, e.g. 16:30.45
    /// Use this to pass dates to DiMe
    static func shortTime() -> String {
        let currentDate = NSDate()
        let dsf = NSDateFormatter()
        dsf.dateFormat = "HH:mm.ss"
        return dsf.stringFromDate(currentDate)
    }

}

extension String {
    
    /// Returns SHA1 digest for this string
    func sha1() -> String {
        let data = self.dataUsingEncoding(NSUTF8StringEncoding)!
        var digest = [UInt8](count:Int(CC_SHA1_DIGEST_LENGTH), repeatedValue: 0)
        CC_SHA1(data.bytes, CC_LONG(data.length), &digest)
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joinWithSeparator("")
    }
    
    /// Trims whitespace and newlines using foundation
    func trimmed() -> String {
        let nss: NSString = self
        return nss.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
    }
    
    /// Checks if this string contains the given character
    func containsChar(theChar: Character) -> Bool {
        for c in self.characters {
            if c == theChar {
                return true
            }
        }
        return false
    }
    
    /// Splits the string, trimming whitespaces, between the given characters (note: slow for very long strings)
    func split(theChar: Character) -> [String]? {
        var outVal = [String]()
        var remainingString = self
        while remainingString.containsChar(theChar) {
            var outString = ""
            var nextChar = remainingString.removeAtIndex(remainingString.startIndex)
            while nextChar != theChar {
                outString.append(nextChar)
                nextChar = remainingString.removeAtIndex(remainingString.startIndex)
            }
            if !outString.trimmed().isEmpty {
                outVal.append(outString.trimmed())
            }
        }
        if !remainingString.trimmed().isEmpty {
            outVal.append(remainingString.trimmed())
        }
        if outVal.count > 0 {
            return outVal
        } else {
            return nil
        }
    }
    
    /// Skips the first x characters
    func skipPrefix(nOfChars: Int) -> String {
        return self.substringFromIndex(self.startIndex.advancedBy(nOfChars))
    }
    
}

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

/// Given an array _ary_ and an index _i_, checks that all items following or preceding ary[i] (within the given stride length, 5 by default) cause prededingFunc(otherItem, ary[i])==True and followingFunc(otherItem, ary[o])==True
///
/// - parameter ary: The input array
/// - parameter index: Where the search starts
/// - parameter strideLength: How far the testing goes
/// - parameter precedingFunc: The function that tests all preceding items (e.g. <)
/// - parameter followingFunc: The function that tests all following items (e.g. >)
/// - returns: True if both functions tests true on all values covered by stride.
func strideArrayTest<T: Comparable>(ary ary: [T], index: Int, strideLength: Int = 5, precedingFunc: (T, T) -> Bool, followingFunc: (T, T) -> Bool) -> Bool {
    var leftI = index - 1
    var rightI = index + 1
    
    while leftI >= 0 && leftI >= index - strideLength {
        if !precedingFunc(ary[leftI], ary[index]) {
            return false
        }
        leftI--
    }
    
    while rightI < ary.count && rightI <= index + strideLength {
        if !followingFunc(ary[rightI], ary[index]) {
            return false
        }
        rightI++
    }
    return true
}

/// Rounds a number to the amount of decimal places specified.
/// Might not be actually be represented as such because computers.
func roundToX(number: CGFloat, places: CGFloat) -> CGFloat {
    return round(number * (pow(10,places))) / pow(10,places)
}

/// Check if a value is within a specified range of another value
///
/// - parameter lhs: The first value
/// - parameter rhs: The second value
/// - parameter range: The allowance
/// - returns: True if lhs is within ± abs(range) of rhs
public func withinRange(lhs: CGFloat, rhs: CGFloat, range: CGFloat) -> Bool {
    return (lhs + abs(range)) >= rhs && (lhs - abs(range)) <= rhs
}

/// Converts centimetre to inches
public func cmToInch(cmValue: CGFloat) -> CGFloat {
    return cmValue * 0.3937
}

/// Converts inches to centimetre
public func inchToCm(inchValue: CGFloat) -> CGFloat {
    return inchValue / 0.3937
}

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
// Contains various functions and utilities not otherwise classified

import Foundation
import Cocoa

/// Given an array _ary_ and an index _i_, checks that all items following or preceding ary[i] (within the given stride length, 5 by default) cause prededingFunc(otherItem, ary[i])==True and followingFunc(otherItem, ary[o])==True
///
/// - parameter ary: The input array
/// - parameter index: Where the search starts
/// - parameter strideLength: How far the testing goes
/// - parameter precedingFunc: The function that tests all preceding items (e.g. <)
/// - parameter followingFunc: The function that tests all following items (e.g. >)
/// - returns: True if both functions tests true on all values covered by stride.
func strideArrayTest<T: Comparable>(ary: [T], index: Int, strideLength: Int = 5, precedingFunc: (T, T) -> Bool, followingFunc: (T, T) -> Bool) -> Bool {
    var leftI = index - 1
    var rightI = index + 1
    
    while leftI >= 0 && leftI >= index - strideLength {
        if !precedingFunc(ary[leftI], ary[index]) {
            return false
        }
        leftI -= 1
    }
    
    while rightI < ary.count && rightI <= index + strideLength {
        if !followingFunc(ary[rightI], ary[index]) {
            return false
        }
        rightI += 1
    }
    return true
}

/// Rounds a number to the amount of decimal places specified.
/// Might not be actually be represented as such because computers.
func roundToX(_ number: CGFloat, places: CGFloat) -> CGFloat {
    return round(number * (pow(10,places))) / pow(10,places)
}

/// Check if a value is within a specified range of another value
///
/// - parameter lhs: The first value
/// - parameter rhs: The second value
/// - parameter range: The allowance
/// - returns: True if lhs is within ± abs(range) of rhs
public func withinRange(_ lhs: CGFloat, rhs: CGFloat, range: CGFloat) -> Bool {
    return (lhs + abs(range)) >= rhs && (lhs - abs(range)) <= rhs
}
 
/// converts centimetres to inches
public func cmToInch(_ cmvalue: CGFloat) -> CGFloat {
    return cmvalue * 0.393701
}

/// converts millimetres to inches
public func mmToInch(_ mmvalue: CGFloat) -> CGFloat {
    return mmvalue * 0.0393701
}

/// Converts inches to centimetre
public func inchToCm(_ inchValue: CGFloat) -> CGFloat {
    return inchValue / 0.393701
}

// MARK: - Other functions

/// Finds i given the condition that ary[i-1] <= target and a[i] > target, using a binary search on
/// a sorted array. Assuming no items are repeated.
///
/// - parameter ary: The sorted array to search
/// - parameter target: The item to search for
/// - returns: The index which corresponds to the item coming immediately after target (or the count of the array if last item <= target), 0 if the beginning of the array > target.
func binaryGreaterOnSortedArray<T: Comparable>(_ ary: [T], target: T) -> Int {
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
func binaryGreaterOrEqOnSortedArray<T: Comparable>(_ ary: [T], target: T) -> Int {
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

/// Returns the size needed to fit the given string, with the given font (of size at
/// most width, after which will be broken on multiple lines)
public func sizeForText(_ str: String, font: NSFont) -> CGSize {
    
    let dd = [NSAttributedStringKey.font: font]
    
    let AS = NSAttributedString(string: str, attributes: dd)
    
    return AS.boundingRect(with: CGSize(width: 200, height: 400), options: NSString.DrawingOptions.usesDeviceMetrics).addTo(2.5).size
}

/// Given a value and an input range, return a value in the output range
public func translate(_ value: Double, leftMin: Double, leftMax: Double, rightMin: Double, rightMax: Double) -> Double {
    // Figure out how 'wide' each range is
    let leftSpan = leftMax - leftMin
    let rightSpan = rightMax - rightMin
    
    // Convert the left range into a 0-1 range (float)
    let valueScaled = (value - leftMin) / leftSpan
    
    // Convert the 0-1 range into a value in the right range.
    return rightMin + (valueScaled * rightSpan)
}

/// Given a value and an input range, return a value in the output range
public func translate(_ value: CGFloat, leftMin: CGFloat, leftMax: CGFloat, rightMin: CGFloat, rightMax: CGFloat) -> CGFloat {
    // Figure out how 'wide' each range is
    let leftSpan = leftMax - leftMin
    let rightSpan = rightMax - rightMin
    
    // Convert the left range into a 0-1 range (float)
    let valueScaled = (value - leftMin) / leftSpan
    
    // Convert the 0-1 range into a value in the right range.
    return rightMin + (valueScaled * rightSpan)
}

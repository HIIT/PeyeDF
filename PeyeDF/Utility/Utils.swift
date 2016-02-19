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
 
/// converts centimetres to inches
public func cmToInch(cmvalue: CGFloat) -> CGFloat {
    return cmvalue * 0.393701
}

/// converts millimetres to inches
public func mmToInch(mmvalue: CGFloat) -> CGFloat {
    return mmvalue * 0.0393701
}

/// Converts inches to centimetre
public func inchToCm(inchValue: CGFloat) -> CGFloat {
    return inchValue / 0.393701
}

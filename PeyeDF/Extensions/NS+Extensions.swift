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
import Cocoa

/// If this value can be checked as "valid" (i.e. is not infinity, nan or other invalid value)
protocol Validable {
    func isValid() -> Bool
}

extension Int: Validable {

    /// Make sure this number of not equal to infinity or nan
    func isValid() -> Bool {
        if self == Int.max || self == Int.min {
            return false
        }
        return true
    }
}

extension Double: Validable {
    
    /// Make sure this number of not equal to infinity or nan
    func isValid() -> Bool {
        let posInf = 1.0/0.0
        if self == posInf {
            return false
        }
        let negInf = -1.0/0.0
        if self == negInf {
            return false
        }
        if self == Double.nan {
            return false
        }
        return true
    }
}

extension NSSize {
    
    /// Returns true if both height and width are within a specified reference
    /// size, within a tolerance (which is a fraction of the given size)
    func withinTolerance(_ reference: NSSize, tolerance: CGFloat) -> Bool {
        let maxWidth = reference.width + reference.width * tolerance
        let maxHeight = reference.height + reference.height * tolerance
        let minWidth = reference.width - reference.width * tolerance
        let minHeight = reference.height - reference.height * tolerance
        return self.height < maxHeight && self.height > minHeight &&
               self.width < maxWidth && self.width > minWidth
    }
    
    /// Returns true if both height and width are **smaller** than a specified reference
    /// size, within a tolerance (which is a fraction of the given size)
    func withinMaxTolerance(_ reference: NSSize, tolerance: CGFloat) -> Bool {
        let maxWidth = reference.width + reference.width * tolerance
        let maxHeight = reference.height + reference.height * tolerance
        return self.height < maxHeight &&
               self.width < maxWidth
    }
    
    func scale(_ factor: CGFloat) -> NSSize {
        var newSize = self
        newSize.width *= factor
        newSize.height *= factor
        return newSize
    }
}

extension NSSize: Hashable {
    public var hashValue: Int { get {
        return self.height.hashValue ^ self.width.hashValue
    } }
}

extension NSColor {
    
    /// Returns true if all the components of the colour (rgb and alpha) are the same as the other color,
    /// ignoring the color space
    ///
    /// - parameter lhs: The color to compare to
    /// - returns: True if they are "practically equal"
    func practicallyEqual(_ lhs: NSColor) -> Bool {
        var components1 = [CGFloat](repeating: -1.0, count: 4)
        var components2 = [CGFloat](repeating: -2.0, count: 4)
        self.getComponents(&components1)
        lhs.getComponents(&components2)
        return components1 == components2
    }
}

extension NSPoint {
    
    /// Creates a point from string specifying 'x,y'
    /// - returns: nil if conversion failed
    init?(string: String) {
        if let spl = string.split(","), spl.count == 2 {
            let nf = NumberFormatter()
            nf.localizesFormat = false  // to be locale-independent
            if let x = nf.number(from: spl[0]) as? CGFloat,
               let y = nf.number(from: spl[1]) as? CGFloat {
                self.x = x
                self.y = y
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    /// Returns a new point in a given rect's coordinate system. In other words,
    /// a poing for which the origin matches the given rectangle's origin
    func pointInRectCoords(_ theRect: NSRect) -> NSPoint {
        return NSPoint(x: self.x - theRect.origin.x, y: self.y - theRect.origin.y)
    }
}

extension NSPoint: Hashable {
    public var hashValue: Int { get {
        return x.hashValue ^ y.hashValue
    } }
}

extension NSPoint: CustomStringConvertible {
    /**
    Format: 'x,y'
    */
    public var description: String { get {
        return "\(self.x),\(self.y)"
    } }
}

extension URLComponents {
    
    /// Returns all parameters and their values in a dictionary.
    /// If there are no parameters, return nil.
    /// Only parameters with a corresponding value are returned.
    var parameterDictionary: [String: String]? { get {
        if let qItems = self.queryItems {
            var retVal = [String: String]()
            for qi in qItems {
                if let val = qi.value {
                    retVal[qi.name] = val
                }
            }
            return retVal
        } else {
            return nil
        }
    } }
    
    /// Sends itself to the given function only if dime is available. Tries to connect to dime.
    /// - parameter mustConnect: If true, proceeds only if dime connects after trying. If false, 
    ///  tries once but then proceeds even if dime is off.
    func onDiMeAvail(_ callback: @escaping ((URLComponents) -> Void), mustConnect: Bool) {
        if DiMePusher.dimeAvailable {
            callback(self)
        } else {
            DiMePusher.dimeConnect() {
                success, _ in
                if !mustConnect || success {
                    callback(self)
                }
            }
        }
    }
}

/// Allows to calculate a hash for collections which contain hashables
extension Collection where Iterator.Element: Hashable {
    
    /// Returns a hash made by starting from 0 and xorring all elements' hashes
    public var xorHash: Int { get {
        return reduce(0, {$0 ^ $1.hashValue})
    } }
}

/// Used to split collection into subsets based on when a "big step" is detected
extension Collection where Index: Strideable, Iterator.Element: Comparable {
    
    /// Splits a collection every time there is a "big enough" difference between
    /// two items (i.e. splits on the boundary).
    /// In other words, splits a collection into multiple subsets based on a given comparison function.
    /// This operation will be performed on a sorted copy of self, and the result(s) will be sorted.
    ///
    /// ### Example:
    /// ```
    /// func isBigStep(p: Int, _ s: Int) -> Bool {
    ///    return s - p > 3 ? true : false
    /// }
    /// ```
    /// The above function is a comparison function that tells that steps above 3 are "big"
    /// ```
    /// let myVals = [1,2,3,22,34,35,36]
    /// returned = myVals.splitOnBigSteps(isBigStep)
    /// ```
    /// the returned value should be `[[1, 2, 3], [22], [34, 35, 36]]`
    /// - Parameter comparison: The comparison function takes two arguments, a preceding and succeeding items.
    /// The collection is split every time the comparison function returns true, so that the
    /// preceding items will be together, and the succeeding items if any placed in subsequent collection(s).
    func splitOnBigSteps<T: Comparable>(_ comparison: (T, T) -> Bool) -> [[T]] {
        
        /// Inner function to repeatedly split the collection into two subsets.
        /// Returns nil when the first is empty.
        /// Otherwise, attempts to split the argument into two sets, what comes before
        /// the big step and what comes after it.
        func innersplit<T>(_ inVal: [T], comparison: (T, T) -> Bool) -> (before: [T], after: [T])? {
            if inVal.isEmpty {
                return nil
            }
            if inVal.count == 1 {
                return (before: inVal, after: [])
            }
            for i in 1..<inVal.count {
                if comparison(inVal[i-1], inVal[i]) {
                    return (before: Array(inVal[0..<i]), after: Array(inVal[i..<inVal.count]))
                }
            }
            return (before: inVal, after: [])
        }
        
        // perform operation on sorted self
        if var converted = (self as? Array<T>) {
            converted.sort()
            
            // first split
            var beforeVals = Array<Array<T>>()
            var s = innersplit(converted, comparison: comparison)
            guard s != nil else {
                // return empty collection of collections if no items are present
                return beforeVals
            }
            beforeVals.append(s!.before)
            // repeatedly split until nothing in `after` is left
            while s != nil && !s!.after.isEmpty {
                s = innersplit(s!.after, comparison: comparison)
                beforeVals.append(s!.before)
            }
            return beforeVals
        } else {
            fatalError("Could not cast collection to an Array (should never happen)")
        }
    }
    
}

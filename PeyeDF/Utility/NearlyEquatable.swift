//
// Copyright (c) 2018 University of Helsinki, Aalto University
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

let FLT_NEARLYEQUAL_DPOINTS = 3  // floats are nearly equal as long as they are equal when rounded to this number of decimal points

protocol NearlyEquatable {
    /// Should return true if two floating-point numbers are separated by less than
    /// FLT_NEARLYEQUAL_DPOINTS decimal points.
    func nearlyEqual(_ other: Self) -> Bool
}

extension NearlyEquatable {
    /// Convenience function to get 10 to the power of the number of decimal points that
    /// we're using (FLT_NEARLYEQUAL_DPOINTS).
    var tenToPow: Double { get {
        return pow(10.0, Double(FLT_NEARLYEQUAL_DPOINTS))
    } }
}

extension Collection where Iterator.Element: NearlyEquatable {
    /// Returns true if the collection contains an element which is
    /// nearly similar to "other"
    func containsSimilar(_ other: Iterator.Element) -> Bool {
        return elementsSimilarTo(other).count > 0
    }
    
    /// Returns all elements which are similar to "other"
    func elementsSimilarTo(_ other: Iterator.Element) -> [Iterator.Element] {
        return self.filter({$0.nearlyEqual(other)})
    }
    
    /// Returns all elements which are not similar to "other"
    func elementsDifferentTo(_ other: Iterator.Element) -> [Iterator.Element] {
        return self.filter({!$0.nearlyEqual(other)})
    }
    
    /// Returns true if all elements in this collection are similar
    /// to at least one element in the other collection (other can contain more elements than this collection).
    func allSimilarTo(_ other: Self) -> Bool {
        return self.reduce(true, {$0 && other.containsSimilar($1)})
    }
    
    /// Returns true if this collection and the other one contain all
    /// elements which are similar to each other (and contain the same number of elements).
    func nearlyEqual(_ other: Self) -> Bool {
        return other.count == self.count && allSimilarTo(other) && other.allSimilarTo(self)
    }
}
extension Float: NearlyEquatable {
    func nearlyEqual(_ other: Float) -> Bool {
        return Int((self * Float(tenToPow)).rounded()) == Int((other * Float(tenToPow)).rounded())
    }
}

extension Double: NearlyEquatable {
    func nearlyEqual(_ other: Double) -> Bool {
        return Int((self * Double(tenToPow)).rounded()) == Int((other * Double(tenToPow)).rounded())
    }
}

extension CGFloat: NearlyEquatable {
    func nearlyEqual(_ other: CGFloat) -> Bool {
        return Int((self * CGFloat(tenToPow)).rounded()) == Int((other * CGFloat(tenToPow)).rounded())
    }
}

extension NSSize: NearlyEquatable {
    func nearlyEqual(_ other: CGSize) -> Bool {
        return self.width.nearlyEqual(other.width) && self.height.nearlyEqual(other.height)
    }
}

extension NSPoint: NearlyEquatable {
    func nearlyEqual(_ other: CGPoint) -> Bool {
        return self.x.nearlyEqual(other.x) && self.y.nearlyEqual(other.y)
    }
}

extension NSRect: NearlyEquatable {
    func nearlyEqual(_ other: CGRect) -> Bool {
        return self.origin.nearlyEqual(other.origin) && self.size.nearlyEqual(other.size)
    }
}

//
//  NearlyEquatable.swift
//  PeyeDF
//
//  Created by Marco Filetti on 29/04/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation
import Cocoa

let FLT_NEARLYEQUAL_DPOINTS = 3  // floats are nearly equal as long as they are equal when rounded to this number of decimal points

protocol NearlyEquatable {
    /// Should return true if two floating-point numbers are separated by less than
    /// FLT_NEARLYEQUAL_DPOINTS decimal points.
    func nearlyEqual(other: Self) -> Bool
}

extension NearlyEquatable {
    /// Convenience function to get 10 to the power of the number of decimal points that
    /// we're using (FLT_NEARLYEQUAL_DPOINTS).
    var tenToPow: Double { get {
        return pow(10.0, Double(FLT_NEARLYEQUAL_DPOINTS))
    } }
}

extension CollectionType where Generator.Element: NearlyEquatable {
    /// Returns true if the collection contains an element which is
    /// nearly similar to "other"
    func containsSimilar(other: Generator.Element) -> Bool {
        return elementsSimilarTo(other).count > 0
    }
    
    /// Returns all elements which are similar to "other"
    func elementsSimilarTo(other: Generator.Element) -> [Generator.Element] {
        return self.filter({$0.nearlyEqual(other)})
    }
    
    /// Returns all elements which are not similar to "other"
    func elementsDifferentTo(other: Generator.Element) -> [Generator.Element] {
        return self.filter({!$0.nearlyEqual(other)})
    }
    
    /// Returns true if all elements in this collection are similar
    /// to at least one element in the other collection (other can contain more elements than this collection).
    func allSimilarTo(other: Self) -> Bool {
        return self.reduce(true, combine: {$0 && other.containsSimilar($1)})
    }
    
    /// Returns true if this collection and the other one contain all
    /// elements which are similar to each other (and contain the same number of elements).
    func nearlyEqual(other: Self) -> Bool {
        return other.count == self.count && allSimilarTo(other) && other.allSimilarTo(self)
    }
}
extension Float: NearlyEquatable {
    func nearlyEqual(other: Float) -> Bool {
        return Int(round(self * Float(tenToPow))) == Int(round(other * Float(tenToPow)))
    }
}

extension Double: NearlyEquatable {
    func nearlyEqual(other: Double) -> Bool {
        return Int(round(self * Double(tenToPow))) == Int(round(other * Double(tenToPow)))
    }
}

extension CGFloat: NearlyEquatable {
    func nearlyEqual(other: CGFloat) -> Bool {
        return Int(round(self * CGFloat(tenToPow))) == Int(round(other * CGFloat(tenToPow)))
    }
}

extension NSSize: NearlyEquatable {
    func nearlyEqual(other: CGSize) -> Bool {
        return CGFloat(round(self.width * CGFloat(tenToPow))) == CGFloat(round(other.width * CGFloat(tenToPow))) &&
               CGFloat(round(self.height * CGFloat(tenToPow))) == CGFloat(round(other.height * CGFloat(tenToPow)))
    }
}

extension NSPoint: NearlyEquatable {
    func nearlyEqual(other: CGPoint) -> Bool {
        return CGFloat(round(self.x * CGFloat(tenToPow))) == CGFloat(round(other.x * CGFloat(tenToPow))) &&
               CGFloat(round(self.y * CGFloat(tenToPow))) == CGFloat(round(other.y * CGFloat(tenToPow)))
    }
}

extension NSRect: NearlyEquatable {
    func nearlyEqual(other: CGRect) -> Bool {
        return self.origin.nearlyEqual(other.origin) && self.size.nearlyEqual(other.size)
    }
}
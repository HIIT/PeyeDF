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
    
    /// Creates a point from string specifying (x,y)
    /// - returns: nil if conversion failed
    init?(string: String) {
        if let spl = string.split(",") where spl.count == 2 {
            let nf = NSNumberFormatter()
            if let x = nf.numberFromString(spl[0]) as? CGFloat,
              y = nf.numberFromString(spl[1]) as? CGFloat {
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
    func pointInRectCoords(theRect: NSRect) -> NSPoint {
        return NSPoint(x: self.x - theRect.origin.x, y: self.y - theRect.origin.y)
    }
}

extension NSURLComponents {
    
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
    func onDiMeAvail(callback: (NSURLComponents -> Void), mustConnect: Bool) {
        if HistoryManager.sharedManager.dimeAvailable {
            callback(self)
        } else {
            HistoryManager.sharedManager.dimeConnect() {
                success in
                if !mustConnect || success {
                    callback(self)
                }
            }
        }
    }
}
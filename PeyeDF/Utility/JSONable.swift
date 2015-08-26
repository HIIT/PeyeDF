//
//  JSONable.swift
//  PeyeDF
//
//  Created by Marco Filetti on 26/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

/// Used to mark items that can return themselves as:
///
/// - NSString
/// - NSNumber
/// - NSArray
/// - NSDictionary
/// - A combination of them
/// Also see NSJSONSerialization help:
/// https://developer.apple.com/library/ios/documentation/Foundation/Reference/NSJSONSerialization_Class/index.html
protocol JSONable {
    
    /// Convert this item into JSONableItem enum.
    /// This makes sure we are only allowed to create items
    /// that can later be decoded by the json serializer.
    func JSONize() -> JSONableItem
    
}

/// Defines items that can be transformed into json
/// JSONable-compliant items must choose one of these to return
enum JSONableItem {
    case Number(NSNumber)
    case String(NSString)
    case Dictionary([NSString: JSONableItem])
    case Array([JSONableItem])
    
    /// Eventually, this method should be called directly by the JSON serializer
    /// to convert the given struct into a "Jsonable" type using something like:
    /// object.JSONize().recurseIntoAny()
    /// where object conforms to the JSONable protocol
    func recurseIntoAny() -> AnyObject {
        switch(self) {
        case .Number(let inputNum):
            return inputNum
        case .String(let inputString):
            return inputString
        case .Array(let inputArray):
            // if this is an array, recursively ask the inner items to "decode" themselves
            var retval = [AnyObject]()
            for elem in inputArray {
                retval.append(elem.recurseIntoAny())
            }
            return retval
        case .Dictionary(let inputDict):
            // make the values decode themselves, while the keys can only be strings
            var retdict = [NSString: AnyObject]()
            for key in inputDict.keys {
                retdict[key] = inputDict[key]!.recurseIntoAny()
            }
            return retdict
        }
    }
}

func == (lhs: ReadingEvent, rhs: ReadingEvent) -> Bool {
    return lhs.multiPage == rhs.multiPage &&
        lhs.visiblePages == rhs.visiblePages &&
        lhs.pageRects == rhs.pageRects &&
        lhs.proportion == rhs.proportion
}

/// Represents a simple range with a start and end value
struct DiMeRange: JSONable, Equatable {
    var min: NSNumber
    var max: NSNumber
    
    /// Returns min and max in a dict
    func JSONize() -> JSONableItem {
        var retDict = [NSString: JSONableItem]()
        retDict["min"] = JSONableItem.Number(min)
        retDict["max"] = JSONableItem.Number(max)
        return .Dictionary(retDict)
    }
}

func == (lhs: DiMeRange, rhs: DiMeRange) -> Bool {
    return lhs.max == rhs.max &&
        lhs.min == rhs.min
}

extension NSRect: JSONable {
    /// Returns origin and size in a dict.
    func JSONize() -> JSONableItem {
        var retDict = [NSString: JSONableItem]()
        retDict["origin"] = self.origin.JSONize()
        retDict["size"] = self.size.JSONize()
        return .Dictionary(retDict)
    }
}

extension CGSize: JSONable {
    /// Returns width and height in a dictionary with their values as
    /// numbers (both as JSONableItem enums).
    func JSONize() -> JSONableItem {
        var retDict = [NSString: JSONableItem]()
        retDict["height"] = JSONableItem.Number(self.height)
        retDict["width"] = JSONableItem.Number(self.width)
        return .Dictionary(retDict)
    }
}

extension CGPoint: JSONable {
    /// Returns x and y in a dictionary with their values as
    /// numbers (both as JSONableItem enums).
    func JSONize() -> JSONableItem {
        var retDict = [NSString: JSONableItem]()
        retDict["x"] = JSONableItem.Number(self.x)
        retDict["y"] = JSONableItem.Number(self.y)
        return .Dictionary(retDict)
    }
}

extension NSDate: JSONable {
    /// Return unix time of date (ms since 1/1/1970)
    func JSONize() -> JSONableItem {
        return .Number(self.unixTime)
    }
}


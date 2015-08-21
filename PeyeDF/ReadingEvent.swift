//
//  DocHistory.swift
//  PeyeDF
//
//  Created by Marco Filetti on 02/07/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//
// Tracking and saving document history (relative to one document; every document has its own history).
// This class bridges PeyeDF's own ReadingEvent struct with a Dictionary suitable for JSON serialization.
// Represent a ReadingEvent in DiMe. Refer to https://github.com/HIIT/PeyeDF/wiki/Data-Format for the data which is passed to DiMe

// implementation:
// We save all data corresponding to an instance of a document read for > 10 seconds
// any "entry" event (key window made, scrolling done) starts a timer
// there can only be one timer
// timer starts with minimum duration, after this passes a copy of the current status is made
// any exit event closes the status (inputting end time and duration)
// exit events are screen saver starts, window lost, scrolling done (note scrolling is both an entry and exit event)
// need to know user's screen saver delay
// timer: http://stackoverflow.com/questions/24369602/using-an-nstimer-in-swift

// start event method
// if there's a timer running (validated property) and create new one
// if timer is already invalidated, still create a new one
// created timer will save current status in new object and set saveStatus boolean to true
// use saveStatus bool when a new timer gets created to check if we need to save status and put in duration, etc
// use NSWindowDidChangeOcclusionStateNotification as an enter/exit event

// remember to start logging if sending window is still key window

// when calculating proportion of pages, remember there are 10 HDPI pixels (5 points) separating pages at size 100%
import Cocoa
import Foundation

struct ReadingEvent: JSONable {
    /// yes if > 1 page is currently being displayed
    var multiPage: Bool
    /// vector of pages specifying the pages currently being displayed, starting from 0 (length should be > 1 if multiPage == true)
    var visiblePages: [Int]
    // A list of rectangles representing where the viewport is placed for each page. All the rects should fit within the page. Rect dimensions refer to points in a 72 dpi space where the bottom left is the origin, as in Apple's PDFKit. A page in US Letter format (often used for papers) translates to approx 594 x 792 points.
    var pageRects: [NSRect]
    
    // Proportion of the page being looked at. Note: this is biased to excess, it gives the very max and min of the proportion of the page beeing looked at. If there is a part currently not being seen in 2-page continuous, it is ignored.
    var proportion: DiMeRange
    
    /// Converts this individual reading event into a dict containing Json-compatible representations for all fields.
    func JSONize() -> JSONableItem {
        var retDict = [NSString: JSONableItem]()
        if multiPage {
            retDict["multiPage"] = JSONableItem.Number(0)
        } else {
            retDict["multiPage"] = JSONableItem.Number(1)
        }
        var retPageArray = [JSONableItem]()
        for pagenum in visiblePages {
            retPageArray.append(JSONableItem.Number(pagenum))
        }
        var retPageRectsArray = [JSONableItem]()
        for pagerect in pageRects {
            retPageRectsArray.append(pagerect.JSONize())
        }
        retDict["visiblePages"] = JSONableItem.Array(retPageArray)
        retDict["pageRects"] = JSONableItem.Array(retPageRectsArray)
        
        retDict["proportion"] = proportion.JSONize()
        return .Dictionary(retDict)
    }
}

/// Represents a simple range with a start and end value
struct DiMeRange: JSONable {
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
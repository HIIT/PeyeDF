//
//  DocHistory.swift
//  PeyeDF
//
//  Created by Marco Filetti on 02/07/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//
// This class bridges PeyeDF's own ReadingEvent struct with a Dictionary suitable for JSON serialization.
// Represent a ReadingEvent in DiMe. Refer to https://github.com/HIIT/PeyeDF/wiki/Data-Format for the data which is passed to DiMe

import Cocoa
import Foundation

struct ReadingEvent: JSONable, Equatable {
    /// yes if > 1 page is currently being displayed
    var multiPage: Bool
    /// vector of pages specifying the pages currently being displayed, starting from 0 (length should be > 1 if multiPage == true)
    var visiblePages: [Int]
    /// A list of rectangles representing where the viewport is placed for each page. All the rects should fit within the page. Rect dimensions refer to points in a 72 dpi space where the bottom left is the origin, as in Apple's PDFKit. A page in US Letter format (often used for papers) translates to approx 594 x 792 points.
    var pageRects: [NSRect]
    
    /// Proportion of the page being looked at. Note: this is biased to excess, it gives the very max and min of the proportion of the page beeing looked at. If there is a part currently not being seen in 2-page continuous, it is ignored.
    var proportion: DiMeRange
    
    /// Plain text visible on-screen
    var plainTextContent: NSString
    
    /// id of the information element (document pointer) related to this event
    var infoElemId: NSString
    
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
        retDict["plainTextContent"] = JSONableItem.String(plainTextContent)
        retDict["@type"] = JSONableItem.String("ReadingEvent")
        
        retDict["type"] = JSONableItem.String("http://www.hiit.fi/ontologies/dime/#ReadingEvent")
        retDict["actor"] = JSONableItem.String("PeyeDF")
        retDict["origin"] = JSONableItem.String("xcode")
        
        retDict["proportion"] = proportion.JSONize()
        
        var infoElemDict = [NSString: JSONableItem]()
        infoElemDict["@type"] = JSONableItem.String("InformationElement")
        infoElemDict["id"] = JSONableItem.String(infoElemId)
        retDict["targettedResource"] = JSONableItem.Dictionary(infoElemDict)
        
        return .Dictionary(retDict)
    }
    
    
}


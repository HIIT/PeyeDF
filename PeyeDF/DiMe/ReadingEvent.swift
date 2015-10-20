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

class ReadingEvent: Event {
    
    var pageEyeData = [[String: AnyObject]]()
    
    /**
        Creates this reading event.
    
        - parameter multiPage: yes if > 1 page is currently being displayed
        - parameter visiblePages: vector of pages specifying the pages currently being displayed, starting from 0 (length should be > 1 if multiPage == true)
        - parameter pageRects: A list of rectangles representing where the viewport is placed for each page. All the rects should fit within the page. Rect dimensions refer to points in a 72 dpi space where the bottom left is the origin, as in Apple's PDFKit. A page in US Letter format (often used for papers) translates to approx 594 x 792 points.
        - parameter isSummary: Whether this event is a "big" summary event, set at the end of reading.
        - parameter proportion: Proportion of the page being looked at. Note: this is biased to excess, it gives the very max and min of the proportion of the page beeing looked at. If there is a part currently not being seen in 2-page continuous, it is ignored. Not set if this is a summary event.
        - parameter plainTextContent: plain text visible on screen
        - parameter scaleFactor: Sale factor of page on screen
        - parameter infoElemId: id referring to the info element referenced by this event (document id)
    */
    init(multiPage: Bool, visiblePageNumbers: [Int], visiblePageLabels: [String], pageRects: [ReadingRect], isSummary: Bool, proportion: DiMeRange?, scaleFactor: NSNumber, plainTextContent: NSString, infoElemId: NSString) {
        super.init()
        
        theDictionary["multiPage"] = multiPage
        theDictionary["visiblePageNumbers"] = visiblePageNumbers
        theDictionary["visiblePageLabels"] = visiblePageLabels
        theDictionary["isSummary"] = isSummary
        if let proportion = proportion {
            theDictionary["proportion"] = proportion.getDict()
        }
        theDictionary["scaleFactor"] = scaleFactor
        theDictionary["plainTextContent"] = plainTextContent
        
        var rectArray = [[String: AnyObject]]()
        for rect in pageRects {
            rectArray.append(rect.getDict())
        }
        theDictionary["pageRects"] = rectArray
        
        
        var infoElemDict = [String: AnyObject]()
        infoElemDict["@type"] = "ScientificDocument"
        infoElemDict["type"] = "http://www.hiit.fi/ontologies/dime/#ScientificDocument"
        infoElemDict["id"] = infoElemId
        
        theDictionary["targettedResource"] = infoElemDict
        
        // dime-required
        theDictionary["@type"] = ("ReadingEvent")
        theDictionary["type"] = ("http://www.hiit.fi/ontologies/dime/#ReadingEvent")
    }
    
    /// Adds eye tracking data to this reading event
    func addEyeData(newData: PageEyeData) {
        pageEyeData.append(newData.getDict())
        theDictionary["pageEyeData"] = pageEyeData
    }
    
}


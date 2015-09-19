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

class ReadingEvent: Event, DiMeAble {
    
    var pageEyeData = [[String: AnyObject]]()
    
    /**
        Creates this reading event.
    
        - parameter multiPage: yes if > 1 page is currently being displayed
        - parameter visiblePages: vector of pages specifying the pages currently being displayed, starting from 0 (length should be > 1 if multiPage == true)
        - parameter pageRects: A list of rectangles representing where the viewport is placed for each page. All the rects should fit within the page. Rect dimensions refer to points in a 72 dpi space where the bottom left is the origin, as in Apple's PDFKit. A page in US Letter format (often used for papers) translates to approx 594 x 792 points.
        - parameter proportion: Proportion of the page being looked at. Note: this is biased to excess, it gives the very max and min of the proportion of the page beeing looked at. If there is a part currently not being seen in 2-page continuous, it is ignored.
    
        - parameter plainTextContent: plain text visible on screen
        - parameter scaleFactor: Sale factor of page on screen
        - parameter infoElemId: id referring to the info element referenced by this event (document id)
    */
    init(multiPage: Bool, visiblePageNumbers: [Int], visiblePageLabels: [String], pageRects: [ReadingRect], proportion: DiMeRange, scaleFactor: NSNumber, plainTextContent: NSString, infoElemId: NSString) {
        super.init()
        self.setDiMeDict()
        json["multiPage"] = JSON(multiPage)
        json["visiblePageNumbers"] = JSON(visiblePageNumbers)
        json["visiblePageLabels"] = JSON(visiblePageLabels)
        json["proportion"] = JSON(proportion.getDict())
        json["scaleFactor"] = JSON(scaleFactor)
        json["plainTextContent"] = JSON(plainTextContent)
        
        var rectArray = [[String: AnyObject]]()
        for rect in pageRects {
            rectArray.append(rect.getDict())
        }
        json["pageRects"] = JSON(rectArray)
        
        
        var infoElemDict = [String: AnyObject]()
        infoElemDict["@type"] = "Document"
        infoElemDict["type"] = "http://www.hiit.fi/ontologies/dime/#Document"
        infoElemDict["id"] = infoElemId
        
        json["targettedResource"] = JSON(infoElemDict)
    }
    
    /// Adds eye tracking data to this reading event
    func addEyeData(newData: PageEyeData) {
        pageEyeData.append(newData.getDict())
        json["pageEyeData"] = JSON(pageEyeData)
    }
    
    func setDiMeDict() {
        json["@type"] = JSON("ReadingEvent")
        json["type"] = JSON("http://www.hiit.fi/ontologies/dime/#ReadingEvent")
    }
    
}


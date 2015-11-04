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
    let infoElemId: NSString
    var manualMarkings: PDFMarkings!
    
    var proportionRead: Double?
    var proportionCritical: Double?
    var proportionInteresting: Double?
    
    /**
        Creates this reading event.
    
        - parameter multiPage: yes if this event refers to multiple pages
        - parameter pages: vector of pages specifying the pages currently being referred to
        - parameter pageRects: A list of rectangles representing relevant paragraphs (interesting, critical, etc). All the rects should fit within their respective pages. Rect dimensions refer to points in a 72 dpi space where the bottom left is the origin, as in Apple's PDFKit. A page in US Letter format (often used for papers) translates to approx 594 x 792 points.
        - parameter isSummary: Whether this event is was sent at the end of reading.
        - parameter plainTextContent: plain text contained within the rectangle
        - parameter scaleFactor: Sale factor of page on screen
        - parameter infoElemId: id referring to the info element referenced by this event (document id)
    */
    init(multiPage: Bool, pageNumbers: [Int], pageLabels: [String], pageRects: [ReadingRect], isSummary: Bool, scaleFactor: NSNumber, plainTextContent: NSString, infoElemId: NSString) {
        self.infoElemId = infoElemId
        super.init()
        
        theDictionary["multiPage"] = multiPage
        theDictionary["pageNumbers"] = pageNumbers
        theDictionary["pageLabels"] = pageLabels
        theDictionary["isSummary"] = isSummary
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
    
    /** Creates a summary reading event, which contains all "markings" in form of rectangles
    */
    init(asSummaryWithMarkings markings: PDFMarkings, plainTextContent: NSString?, infoElemId: NSString, proportionTriple: (proportionRead: Double, proportionInteresting: Double, proportionCritical: Double)) {
        self.infoElemId = infoElemId
        
        self.proportionRead = proportionTriple.proportionRead
        self.proportionCritical = proportionTriple.proportionCritical
        self.proportionInteresting = proportionTriple.proportionInteresting
        
        super.init()
        
        theDictionary["proportionRead"] = proportionTriple.proportionRead
        theDictionary["proportionInteresting"] = proportionTriple.proportionInteresting
        theDictionary["proportionCritical"] = proportionTriple.proportionCritical
        
        theDictionary["isSummary"] = true
        
        // create a rectangle array for all PDF markings
        var rectArray = [[String: AnyObject]]()
        for rect in markings.getAllReadingRects() {
            rectArray.append(rect.getDict())
        }
        theDictionary["pageRects"] = rectArray
        
        if let ptc = plainTextContent {
            theDictionary["plainTextContent"] = ptc
        }
        
        var infoElemDict = [String: AnyObject]()
        infoElemDict["@type"] = "ScientificDocument"
        infoElemDict["type"] = "http://www.hiit.fi/ontologies/dime/#ScientificDocument"
        infoElemDict["id"] = infoElemId
        
        theDictionary["targettedResource"] = infoElemDict
        
        // dime-required
        theDictionary["@type"] = ("ReadingEvent")
        theDictionary["type"] = ("http://www.hiit.fi/ontologies/dime/#ReadingEvent")
    }
    
    /// Creates event from dime. NOTE: such events cannot be sent back to dime
    init(asManualSummaryFromDime json: JSON) {
        infoElemId = json["targettedResource"]["id"].stringValue
        proportionRead = json["proportionRead"].doubleValue
        proportionInteresting = json["proportionInteresting"].doubleValue
        proportionCritical = json["proportionCritical"].doubleValue
        let dateCreated: NSDate = NSDate(timeIntervalSince1970: NSTimeInterval(json["timeCreated"].intValue / 1000))
        self.manualMarkings = PDFMarkings(withSource: ClassSource.Click)
        for pageRect in json["pageRects"].arrayValue {
            if pageRect["classSource"].intValue == ClassSource.Click.rawValue {
                self.manualMarkings.addRect(ReadingRect(fromJson: pageRect))
            }
        }
        super.init(withStartDate: dateCreated)
    }
    
    /// Adds eye tracking data to this reading event
    func addEyeData(newData: PageEyeData) {
        pageEyeData.append(newData.getDict())
        theDictionary["pageEyeData"] = pageEyeData
    }
    
}


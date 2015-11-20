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
    
    let sessionId: String
    
    var pageEyeData = [[String: AnyObject]]()
    let infoElemId: NSString
    var pageRects: [ReadingRect]
    
    var proportionRead: Double?
    var proportionCritical: Double?
    var proportionInteresting: Double?
    
    var foundStrings = [String]()
    var isSummary: Bool
    
    var pageLabels: [String]?
    var pageNumbers: [Int]?
    var scaleFactor: NSNumber?
    
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
    init(multiPage: Bool, sessionId: String, pageNumbers: [Int], pageLabels: [String], pageRects: [ReadingRect], isSummary: Bool, scaleFactor: NSNumber, plainTextContent: NSString, infoElemId: NSString) {
        self.infoElemId = infoElemId
        self.sessionId = sessionId
        self.pageLabels = pageLabels
        self.pageNumbers = pageNumbers
        self.pageRects = pageRects
        self.scaleFactor = scaleFactor
        self.isSummary = isSummary
        super.init()
        
        theDictionary["plainTextContent"] = plainTextContent
        
    }
    
    /** Creates a summary reading event, which contains all "markings" in form of rectangles
    */
    init(asSummaryWithRects rects: [ReadingRect], sessionId: String, plainTextContent: NSString?, infoElemId: NSString, foundStrings: [String], pdfReader: MyPDFReader?, proportionTriple: (proportionRead: Double, proportionInteresting: Double, proportionCritical: Double)) {
        self.infoElemId = infoElemId
        self.sessionId = sessionId
        
        self.proportionRead = proportionTriple.proportionRead
        self.proportionCritical = proportionTriple.proportionCritical
        self.proportionInteresting = proportionTriple.proportionInteresting
        self.foundStrings = foundStrings
        self.pageRects = rects
        self.isSummary = true
        
        super.init()
        
        if let ptc = plainTextContent {
            theDictionary["plainTextContent"] = ptc
        }
        
        self.foundStrings.appendContentsOf(foundStrings)
    }
    
    /// Creates event from dime. NOTE: sending these events back to dime is untested.
    init(asManualSummaryFromDime json: JSON) {
        infoElemId = json["targettedResource"][PeyeConstants.iId].stringValue
        sessionId = json["sessionId"].stringValue
        isSummary = json["isSummary"].boolValue
        proportionRead = json["proportionRead"].doubleValue
        proportionInteresting = json["proportionInteresting"].doubleValue
        proportionCritical = json["proportionCritical"].doubleValue
        if let fStrings = json["foundStrings"].array {
            for fString in fStrings {
                foundStrings.append(fString.stringValue)
            }
        }
        let dateCreated: NSDate = NSDate(timeIntervalSince1970: NSTimeInterval(json["start"].intValue / 1000))
        self.pageRects = [ReadingRect]()
        for pageRect in json["pageRects"].arrayValue {
            self.pageRects.append(ReadingRect(fromJson: pageRect))
        }
        super.init(withStartDate: dateCreated)
        
        // create dictionary directly from json (result untested)
        theDictionary = json.dictionaryObject!
        
    }
    
    /// Adds eye tracking data to this reading event
    func addEyeData(newData: PageEyeData) {
        pageEyeData.append(newData.getDict())
        theDictionary["pageEyeData"] = pageEyeData
    }
    
    /// Adds a reading rect to the current rectangle list of
    /// manually - entered markings
    func addRect(newRect: ReadingRect) {
        self.pageRects.append(newRect)
    }
    
    /// Returns dictionary for this reading event. Overridden to allow custom values
    override func getDict() -> [String : AnyObject] {
        var retDict = theDictionary
        
        retDict["sessionId"] = sessionId
        retDict["isSummary"] = isSummary
        
        if let plabels = self.pageLabels {
            retDict["pageLabels"] = plabels
        }
        if let pnumbers = self.pageNumbers {
            retDict["pageNumbers"] = pnumbers
        }
        if let sfactor = self.scaleFactor {
            retDict["scaleFactor"] = sfactor
        }
        
        if let pread = proportionRead {
            retDict["proportionRead"] = pread
        }
        if let pinter = proportionInteresting {
            retDict["proportionInteresting"] = pinter
        }
        if let pcrit = proportionCritical {
            retDict["proportionCritical"] = pcrit
        }
        
        if foundStrings.count > 0 {
            theDictionary["foundStrings"] = foundStrings
        }
        
        var rectArray = [[String: AnyObject]]()
        for rect in pageRects {
            rectArray.append(rect.getDict())
        }
        retDict["pageRects"] = rectArray
        
        var infoElemDict = [String: AnyObject]()
        infoElemDict["@type"] = "ScientificDocument"
        infoElemDict["type"] = "http://www.hiit.fi/ontologies/dime/#ScientificDocument"
        infoElemDict[PeyeConstants.iId] = infoElemId
        
        retDict["targettedResource"] = infoElemDict
        
        // dime-required
        retDict["@type"] = ("ReadingEvent")
        retDict["type"] = ("http://www.hiit.fi/ontologies/dime/#ReadingEvent")
        
        return retDict
    }
}


//
//  SummaryReadingEvent.swift
//  PeyeDF
//
//  Created by Marco Filetti on 17/12/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Foundation

class SummaryReadingEvent: ReadingEvent {
    
    
    private(set) var proportionRead: Double?
    private(set) var proportionCritical: Double?
    private(set) var proportionInteresting: Double?
    
    private(set) var foundStrings = [String]()
    
    
    /** Creates a summary reading event, which contains all "markings" in form of rectangles
    */
    required init(rects: [ReadingRect], sessionId: String, plainTextContent: NSString?, infoElemId: NSString, foundStrings: [String], pdfReader: MyPDFReader?, proportionRead: Double, proportionInteresting: Double, proportionCritical: Double) {
        
        self.proportionRead = proportionRead
        self.proportionCritical = proportionCritical
        self.proportionInteresting = proportionInteresting
        self.foundStrings = foundStrings
        
        super.init(sessionId: sessionId, pageNumbers: nil, pageLabels: nil, pageRects: rects,  plainTextContent: plainTextContent, infoElemId: infoElemId)
        
        self.foundStrings.appendContentsOf(foundStrings)
    }
    
    required init(fromDime json: JSON) {
        if let fStrings = json["foundStrings"].array {
            for fString in fStrings {
                foundStrings.append(fString.stringValue)
            }
        }
        proportionRead = json["proportionRead"].double
        proportionInteresting = json["proportionInteresting"].double
        proportionCritical = json["proportionCritical"].double
        super.init(fromDime: json)
    }
    
    override func getDict() -> [String : AnyObject] {
        var retDict = super.getDict()
        
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
            retDict["foundStrings"] = foundStrings
        }
        
        // dime-required
        retDict["@type"] = ("SummaryReadingEvent")
        retDict["type"] = ("http://www.hiit.fi/ontologies/dime/#SummaryReadingEvent")
        
        return retDict
    }
}
//
// Copyright (c) 2015 Aalto University
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

import Cocoa
import Foundation

// This class bridges PeyeDF's own ReadingEvent struct with a Dictionary suitable for JSON serialization.
// Represent a ReadingEvent in DiMe. Refer to https://github.com/HIIT/PeyeDF/wiki/Data-Format for the data which is passed to DiMe
class ReadingEvent: Event, NSCopying {
    
    let sessionId: String
    var previousSessionId: String?
    
    /// Associated scientific document (set only when we receive from dime
    fileprivate(set) var targettedResource: ScientificDocument?
    
    /// page eye data can only be modified by addEyeData(...), can't be initialized
    fileprivate(set) var pageEyeData = [PageEyeDataChunk]()
    
    let infoElemId: String
    fileprivate(set) var pageRects: [ReadingRect]
    
    fileprivate(set) var pageLabels: [String]?
    fileprivate(set) var pageNumbers: [Int]?
    
    fileprivate(set) var plainTextContent: String?
    fileprivate(set) var dpi: Int?
    
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
    init(sessionId: String, pageNumbers: [Int]?, pageLabels: [String]?, pageRects: [ReadingRect], plainTextContent: String?, infoElemId: String) {
        self.infoElemId = infoElemId
        self.sessionId = sessionId
        self.pageLabels = pageLabels
        if let dp = AppSingleton.getComputedDPI() {
            dpi = dp
        } else {
            dpi = AppSingleton.getMonitorDPI()
        }
        self.pageNumbers = pageNumbers
        self.pageRects = pageRects
        self.plainTextContent = plainTextContent
        super.init()
    }
    
    /// Creates an event from a json supplied in the dime format.
    required init(fromDime json: JSON) {
        infoElemId = json["targettedResource"]["appId"].stringValue
        sessionId = json["sessionId"].stringValue
        
        //optionals
        plainTextContent = json["plainTextContent"].string
        dpi = json["dpi"].int
        if let psi = json["previousSessionId"].string {
            previousSessionId = psi
        }
        if let pns = json["pageNumbers"].arrayObject {
            pageNumbers = pns as? [Int]
        }
        if let pls = json["pageLabels"].arrayObject {
            pageLabels = pls as? [String]
        }
        if let pedata = json["pageEyeData"].array {
            for chunk in pedata {
                pageEyeData.append(PageEyeDataChunk(fromDime: chunk))
            }
        }
        if json["targettedResource"].exists() {
            targettedResource = ScientificDocument(fromDime: json["targettedResource"])
        }
        
        let dateCreated: Date = Date(timeIntervalSince1970: TimeInterval(json["start"].intValue / 1000))
        self.pageRects = [ReadingRect]()
        for pageRect in json["pageRects"].arrayValue {
            self.pageRects.append(ReadingRect(fromJson: pageRect))
        }
        
        super.init(withStartDate: dateCreated)
        
        if let id = json["id"].int {
            super.setId(id)
        }
    }
    
    /// Adds eye tracking data to this reading event
    func addEyeData(_ newData: PageEyeDataChunk) {
        pageEyeData.append(newData)
    }
    
    /// Adds a reading rect to the current rectangle list
    func addRect(_ newRect: ReadingRect) {
        self.pageRects.append(newRect)
    }
    
    /// Appends a list of reading rects to the current rectangle list
    func extendRects(_ newRects: [ReadingRect]) {
        self.pageRects.append(contentsOf: newRects)
    }
    
    /// Sets current rects with a new set of rects.
    /// - Warning: This can break associations between page numbers and eye data chunks, make
    /// sure this is not done across events coming from different sources.
    func setRects(_ newRects: [ReadingRect]) {
        pageRects = newRects
    }
    
    /// Returns dictionary for this reading event. Overridden to allow custom values
    override func getDict() -> [String : Any] {
        var retDict = theDictionary
        
        retDict["sessionId"] = sessionId
        if let psi = previousSessionId {
            retDict["previousSessionId"] = psi
        }
        if let plabels = self.pageLabels {
            retDict["pageLabels"] = plabels
        }
        if let pnumbers = self.pageNumbers {
            retDict["pageNumbers"] = pnumbers
        }
        if let ptc = plainTextContent {
            retDict["plainTextContent"] = ptc
        }
        if let dp = dpi {
            retDict["dpi"] = dp
        }
        if pageEyeData.count > 0 {
            retDict["pageEyeData"] = pageEyeData.asDictArray()
        }
        retDict["pageRects"] = pageRects.asDictArray()
        
        var infoElemDict = [String: Any]()
        infoElemDict["@type"] = "ScientificDocument"
        infoElemDict["type"] = "http://www.hiit.fi/ontologies/dime/#ScientificDocument"
        infoElemDict["appId"] = infoElemId
        
        retDict["targettedResource"] = infoElemDict
        
        // dime-required
        retDict["@type"] = ("ReadingEvent")
        retDict["type"] = ("http://www.hiit.fi/ontologies/dime/#ReadingEvent")
        
        return retDict
    }
    
    /// Makes a deep copy of itself
    ///
    /// - parameter zone: this parameter is ignored
    func copy(with zone: NSZone?) -> Any {
        let newEvent = ReadingEvent(sessionId: self.sessionId, pageNumbers: self.pageNumbers!, pageLabels: self.pageLabels!, pageRects: self.pageRects, plainTextContent: plainTextContent, infoElemId: self.infoElemId)
        newEvent.dpi = self.dpi
        return newEvent
    }
}


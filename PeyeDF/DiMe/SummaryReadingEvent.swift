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

import Foundation

class SummaryReadingEvent: ReadingEvent {
    
    /// Total time spent reading the document (sec).
    /// Set this before submitting event to dime if we want this to be sent.
    var readingTime: Double?
    
    fileprivate(set) var proportionRead: Double?
    fileprivate(set) var proportionCritical: Double?
    fileprivate(set) var proportionInteresting: Double?
    
    fileprivate(set) var foundStrings = [String]()
    
    
    /** Creates a summary reading event, which contains all "markings" in form of rectangles
    */
    required init(rects: [ReadingRect], sessionId: String, plainTextContent: String?, infoElemId: String, foundStrings: [String], proportionRead: Double, proportionInteresting: Double, proportionCritical: Double) {
        
        self.proportionRead = proportionRead
        self.proportionCritical = proportionCritical
        self.proportionInteresting = proportionInteresting
        self.foundStrings = foundStrings
        
        super.init(sessionId: sessionId, pageNumbers: nil, pageLabels: nil, pageRects: rects,  plainTextContent: plainTextContent, infoElemId: infoElemId)
        
        self.foundStrings.append(contentsOf: foundStrings)
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
        readingTime = json["readingTime"].double
        super.init(fromDime: json)
    }
    
    override func getDict() -> [String : Any] {
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
        if let rtime = readingTime {
            retDict["readingTime"] = rtime
        }
        if foundStrings.count > 0 {
            retDict["foundStrings"] = foundStrings
        }
        
        // dime-required
        retDict["@type"] = ("SummaryReadingEvent")
        retDict["type"] = ("http://www.hiit.fi/ontologies/dime/#SummaryReadingEvent")
        
        return retDict
    }
    
    /// Overwrite the current set of read/critical/interesting values
    func setProportions(_ pRead: Double, pInteresting: Double, pCritical: Double) {
        self.proportionRead = pRead
        self.proportionInteresting = pInteresting
        self.proportionCritical = pCritical
    }
}

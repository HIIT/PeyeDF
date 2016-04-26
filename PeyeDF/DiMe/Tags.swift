//
//  Tag.swift
//  PeyeDF
//
//  Created by Marco Filetti on 22/04/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation

public class Tag: Dictionariable, Equatable {
    
    let text: String
    
    init(withText: String) {
        self.text = withText
    }
    
    init(fromDiMe json: JSON) {
        self.text = json["text"].stringValue
    }
    
    func getDict() -> [String : AnyObject] {
        var theDictionary = [String: AnyObject]()
        
        theDictionary["text"] = text
        theDictionary["@type"] = "Tag"
    
        if let hostname = NSHost.currentHost().name {
            theDictionary["origin"] = hostname
        }
        
        return theDictionary
    }
}

public class SubDocumentTag: Tag {
    
    let pageRects: [ReadingRect]
    
    /// Creates a new tag. Rects' scalefactor will be set to -1.
    init(text: String, withRects: [NSRect], pages: [Int], pdfBase: MyPDFBase?) {
        var pageRects = [ReadingRect]()
        
        for (n, r) in withRects.enumerate() {
            var r = ReadingRect(pageIndex: pages[n], rect: r, readingClass: .Tag, classSource: .Click, pdfBase: pdfBase)
            r.scaleFactor = -1
            pageRects.append(r)
        }
        
        self.pageRects = pageRects
        super.init(withText: text)
    }
    
    override init(fromDiMe json: JSON) {
        self.pageRects = json["pageRects"].arrayValue.flatMap({ReadingRect(fromJson: $0)})
        super.init(fromDiMe: json)
    }
    
    override func getDict() -> [String : AnyObject] {
        var theDictionary = super.getDict()
        theDictionary["pageRects"] = pageRects.asDictArray()
        theDictionary["@type"] = "SubDocumentTag"
        return theDictionary
    }
}

public func == (lhs: Tag, rhs: Tag) -> Bool {
    return lhs.text == rhs.text
}

public func == (lhs: SubDocumentTag, rhs: SubDocumentTag) -> Bool {
    return lhs.text == rhs.text
}

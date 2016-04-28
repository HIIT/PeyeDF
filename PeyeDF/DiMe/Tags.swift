//
//  Tag.swift
//  PeyeDF
//
//  Created by Marco Filetti on 22/04/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation

public class Tag: Dictionariable, Equatable, Hashable {
    
    public var hashValue: Int { get {
        return text.hashValue
    } }
    
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

public class ReadingTag: Tag {
    
    override public var hashValue: Int { get {
        return rects.reduce(super.hashValue, combine: {$0 ^ $1.hashValue})
    } }
    
    let rects: [ReadingRect]
    
    /// Creates a new tag. Rects' scalefactor will be set to -1.
    init(text: String, withRects: [NSRect], pages: [Int], pdfBase: MyPDFBase?) {
        var pageRects = [ReadingRect]()
        
        for (n, r) in withRects.enumerate() {
            var r = ReadingRect(pageIndex: pages[n], rect: r, readingClass: .Tag, classSource: .Click, pdfBase: pdfBase)
            r.scaleFactor = -1
            pageRects.append(r)
        }
        
        self.rects = pageRects
        super.init(withText: text)
    }
    
    override init(fromDiMe json: JSON) {
        self.rects = json["rects"].arrayValue.flatMap({ReadingRect(fromJson: $0)})
        super.init(fromDiMe: json)
    }
    
    override func getDict() -> [String : AnyObject] {
        var theDictionary = super.getDict()
        theDictionary["rects"] = rects.asDictArray()
        theDictionary["@type"] = "ReadingTag"
        return theDictionary
    }
    
    /// Returns true if the given NSRect is part of this tag's rects
    func containsNSRect(nsrect: NSRect) -> Bool {
        return self.rects.reduce(false, combine: {$0 || $1.rect == nsrect})
    }
    
    /// Returns true if the given collection of NSRects corresponds to this tag's rects
    func containsNSRects(nsrects: [NSRect]) -> Bool {
        return nsrects.reduce(true, combine: {$0 && containsNSRect($1)})
    }
}

public func == (lhs: Tag, rhs: Tag) -> Bool {
    return lhs.text == rhs.text
}

public func == (lhs: ReadingTag, rhs: ReadingTag) -> Bool {
    return lhs.text == rhs.text && lhs.rects == rhs.rects
}

func makeTag(fromJson json: JSON) -> Tag? {
    if json["@type"].stringValue == "Tag" {
        return Tag(fromDiMe: json)
    } else if json["@type"].stringValue == "ReadingTag" {
        return ReadingTag(fromDiMe: json)
    } else {
        AppSingleton.log.error("Unrecognized tag @type")
        return nil
    }
}

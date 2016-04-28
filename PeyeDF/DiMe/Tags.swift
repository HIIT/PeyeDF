//
//  Tag.swift
//  PeyeDF
//
//  Created by Marco Filetti on 22/04/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation

public class Tag: Dictionariable, Equatable, Hashable {
    
    /// Creates a tag of the correct type depending on the json's type annotation
    static func makeTag(fromJson json: JSON) -> Tag? {
        if json["@type"].stringValue == "Tag" {
            return Tag(fromDiMe: json)
        } else if json["@type"].stringValue == "ReadingTag" {
            return ReadingTag(fromDiMe: json)
        } else {
            AppSingleton.log.error("Unrecognized tag @type")
            return nil
        }
    }
    
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
    
    /// Returns true if the given NSRect is part of this tag's rects, on the given page
    func containsNSRect(nsrect: NSRect, onPage: Int) -> Bool {
        return self.rects.reduce(false, combine: {$0 || ($1.rect == nsrect && $1.pageIndex == onPage)})
    }
    
    /// Returns true if the given collection of NSRects corresponds to this tag's rects
    func containsNSRects(nsrects: [NSRect], onPages: [Int]) -> Bool {
        return nsrects.enumerate().reduce(true, combine: {$0 && containsNSRect($1.element, onPage: onPages[$1.index])})
    }
}

/// Checks if two tags are equal (and if they are both reading tags, uses the reading tag
/// specific comparison)
public func == (lhs: Tag, rhs: Tag) -> Bool {
    if lhs.dynamicType == rhs.dynamicType {
        if let rrl = lhs as? ReadingTag, rrr = rhs as? ReadingTag {
            return rrl == rrr
        } else {
            return lhs.text == rhs.text
        }
    } else {
        return false
    }
}

public func == (lhs: ReadingTag, rhs: ReadingTag) -> Bool {
    return lhs.text == rhs.text && lhs.rects == rhs.rects
}
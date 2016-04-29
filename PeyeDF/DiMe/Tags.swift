//
//  Tag.swift
//  PeyeDF
//
//  Created by Marco Filetti on 22/04/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation

public class Tag: Dictionariable, Equatable {
    
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
    
    /// All parts of the document referenced by this tag (not necessarily in order).
    private(set) var rects: [ReadingRect]
    
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
    
    /// Creates a new tag from another tag.
    init(fromTag: ReadingTag) {
        rects = fromTag.rects
        super.init(withText: fromTag.text)
    }
    
    /// Combines this tag with another, and returns the new tag.
    /// In other words, adds the parts of document referenced by the new tag with "these" parts of a document.
    /// Used to combine two tags with the same text but that refer to different parts of a document.
    func combine(otherTag: ReadingTag) -> ReadingTag {
        let newTag = ReadingTag(fromTag: self)
        // only append rects which are not already in this tag
        newTag.rects.appendContentsOf(otherTag.rects.filter({!newTag.rects.containsSimilar($0)}))
        return newTag
    }
    
    /// Removes the rects contained given tag from this one, and returns a new tag.
    /// The new tag will be a simple Tag (with just text) if no rects are left.
    func subtract(otherTag: ReadingTag) -> Tag {
        let newTag = ReadingTag(fromTag: self)
        // get all rects which are not in othertag
        newTag.rects = newTag.rects.filter({!otherTag.rects.containsSimilar($0)})
        // if something is left, return the result (as a ReadingTag), otherwise a simple tag.
        if newTag.rects.count > 0 {
            return newTag
        } else {
            return Tag(withText: newTag.text)
        }
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
        return self.rects.reduce(false, combine: {$0 || ($1.rect.nearlyEqual(nsrect) && $1.pageIndex == onPage)})
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

/// Note: two ReadingTags are equal even when all their rects are all *nearly* equal
public func == (lhs: ReadingTag, rhs: ReadingTag) -> Bool {
    return lhs.text == rhs.text && lhs.rects.nearlyEqual(rhs.rects)
}

extension CollectionType where Generator.Element: Tag {
    
    /// Returns true if at least one tag in the collection has the given text.
    func containsTag(withText text: String) -> Bool {
        return self.reduce(false, combine: {$0 || $1.text == text})
    }
    
    /// Returns the tag which has the given text (if any, nil otherwise)
    func getTag(withText: String) -> Tag? {
        let retVal = self.filter({$0.text == withText})
        if retVal.count >= 1 {
            if retVal.count > 1 {
                AppSingleton.log.error("More than one tag with a given corresponding text was found. This should never happen")
            }
            return retVal[0]
        } else {
            return nil
        }
    }

    /// Returns readingtags which refer to the given rects on the given pages.
    /// - Parameter forRects: Rectangles which cover the areas that should be tagged.
    /// - Parameter onPages: Page indices on which the rects appear (same order as forRects).
    func getReadingTags(forRects: [NSRect], onPages: [Int]) -> [ReadingTag] {
        let rTags = self.flatMap({$0 as? ReadingTag})
        return rTags.filter({$0.containsNSRects(forRects, onPages: onPages)})
    }
}
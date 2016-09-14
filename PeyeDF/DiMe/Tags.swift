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

open class Tag: Dictionariable, Equatable, CustomStringConvertible {
    
    /// The tag's description is the tag's text
    open var description: String { get {
        return self.text
    } }
    
    /// The actual text of the tag (or its "name")
    let text: String
    
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
    
    open var hashValue: Int { get {
        return text.hashValue
    } }
    
    init(withText: String) {
        self.text = withText
    }
    
    init(fromDiMe json: JSON) {
        self.text = json["text"].stringValue
    }
    
    func getDict() -> [String : Any] {
        var theDictionary = [String: Any]()
        
        theDictionary["text"] = text
        theDictionary["@type"] = "Tag"
    
        if let hostname = Host.current().name {
            theDictionary["origin"] = hostname
        }
        
        return theDictionary
    }
}

open class ReadingTag: Tag {
    
    /// All parts of the document referenced by this tag.
    fileprivate(set) var rRects: [ReadingRect]
    
    /// The ReadingTag has a more complex description, which includes
    /// rects and pages associated to it.
    /// Format: `tagName:<pages>::<rects>` where pages and rects are separated by `;`,
    /// and each page has one rect associated to it.
    /// For example: `a tag:1;2::0,0,20,30;1,1,40,50`
    /// (rects are x,y,w,h).
    override open var description: String { get {
        let pages = self.rRects.map {String(describing: $0.pageIndex)} .joined(separator: ";")
        let rects = self.rRects.map {$0.rect.description} .joined(separator: ";")
        return self.text + ":" + pages + "::" + rects
    } }
    
    /// Creates a new tag. Rects' scalefactor will be set to -1.
    init(text: String, withRects: [NSRect], pages: [Int], pdfBase: PDFBase?) {
        var pageRects = [ReadingRect]()
        
        for (n, r) in withRects.enumerated() {
            var r = ReadingRect(pageIndex: pages[n], rect: r, readingClass: .tag, classSource: .click, pdfBase: pdfBase)
            r.scaleFactor = -1
            pageRects.append(r)
        }
        
        self.rRects = pageRects
        super.init(withText: text)
    }
    
    /// Creates a new tag from another tag.
    init(fromTag: ReadingTag) {
        rRects = fromTag.rRects
        super.init(withText: fromTag.text)
    }
    
    /// Creates a new tag from another tag, but with different text
    init(withText: String, fromTag: ReadingTag) {
        rRects = fromTag.rRects
        super.init(withText: withText)
    }
    
    /// Creates new tag with a given text, with predefined ReadingRects
    init(withRects: [ReadingRect], withText: String) {
        rRects = withRects
        super.init(withText: withText)
    }
    
    /// Creates a new tag from a string (such as the one created by calling .description)
    convenience init?(fromString string: String, pdfBase: PDFBase?) {
        guard let pr = string.range(of: ":") else {
            return nil
        }
        
        let text = string.substring(to: pr.lowerBound)
        let suffix = string.substring(from: pr.upperBound)
        let components = suffix.components(separatedBy: "::")
        
        guard components.count == 2 else {
            AppSingleton.log.error("Unexpected number of components. Input was:\n\(string)")
            return nil
        }
        
        let pagesString = components[0]
        let rectsString = components[1]
        
        let pages = pagesString.components(separatedBy: ";").flatMap {Int($0)}
        let rects = rectsString.components(separatedBy: ";").flatMap {NSRect(string: $0)}
        
        guard pages.count == rects.count else {
            AppSingleton.log.error("Pages and rect counts do not match. Input was:\n\(string)")
            return nil
        }
        
        self.init(text: text, withRects: rects, pages: pages, pdfBase: pdfBase)
    }
    
    /// Combines this tag with another, and returns the new tag.
    /// In other words, adds the parts of document referenced by the new tag with "these" parts of a document.
    /// Used to combine two tags with the same text but that refer to different parts of a document.
    func combine(_ otherTag: ReadingTag) -> ReadingTag {
        let newTag = ReadingTag(fromTag: self)
        // only append rects which are not already in this tag
        newTag.rRects.append(contentsOf: otherTag.rRects.filter({!newTag.rRects.containsSimilar($0)}))
        return newTag
    }
    
    /// Removes the rects contained given tag from this one, and returns a new tag.
    /// The new tag will be a simple Tag (with just text) if no rects are left.
    func subtract(_ otherTag: ReadingTag) -> Tag {
        let newTag = ReadingTag(fromTag: self)
        // get all rects which are not in othertag
        newTag.rRects = newTag.rRects.filter({!otherTag.rRects.containsSimilar($0)})
        // if something is left, return the result (as a ReadingTag), otherwise a simple tag.
        if newTag.rRects.count > 0 {
            return newTag
        } else {
            return Tag(withText: newTag.text)
        }
    }
    
    override init(fromDiMe json: JSON) {
        self.rRects = json["rects"].arrayValue.flatMap({ReadingRect(fromJson: $0)})
        super.init(fromDiMe: json)
    }
    
    override func getDict() -> [String : Any] {
        var theDictionary = super.getDict()
        theDictionary["rects"] = rRects.asDictArray()
        theDictionary["@type"] = "ReadingTag"
        return theDictionary
    }
    
    /// Returns true if the given NSRect is part of this tag's rects, on the given page
    func containsNSRect(_ nsrect: NSRect, onPage: Int) -> Bool {
        return self.rRects.reduce(false, {$0 || ($1.rect.nearlyEqual(nsrect) && $1.pageIndex == onPage)})
    }
    
    /// Returns true if the given collection of NSRects corresponds to this tag's rects
    func containsNSRects(_ nsrects: [NSRect], onPages: [Int]) -> Bool {
        return nsrects.enumerated().reduce(true, {$0 && containsNSRect($1.element, onPage: onPages[$1.offset])})
    }
    
    /// Returns the difference in terms of ReadingRect between this and another ReadingTag.
    /// Returns a tuple with the ReadingRects which have been added in other (relative complement of this in other)
    /// and the ReadingRects which have been removed (relative complement of other in this).
    /// Generates a fatalError if the tags' texts are not the same.
    func rectDifference(_ other: ReadingTag) -> (added: [ReadingRect], removed: [ReadingRect]) {
        if self.text != other.text {
            fatalError("Taking difference of two tags with different text!")
        }
        var added = [ReadingRect]()
        for r in other.rRects {
            if !self.rRects.containsSimilar(r) {
                added.append(r)
            }
        }
        var removed = [ReadingRect]()
        for r in self.rRects {
            if !other.rRects.containsSimilar(r) {
                removed.append(r)
            }
        }
        return (added: added, removed: removed)
    }
    
}

/// Checks if two tags are equal (and if they are both reading tags, uses the reading tag
/// specific comparison)
public func == (lhs: Tag, rhs: Tag) -> Bool {
    if type(of: lhs) == type(of: rhs) {
        if let rrl = lhs as? ReadingTag, let rrr = rhs as? ReadingTag {
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
    return lhs.text == rhs.text && lhs.rRects.nearlyEqual(rhs.rRects)
}

extension Collection where Iterator.Element: Tag {
    
    /// Returns true if at least one tag in the collection has the given text.
    func containsTag(withText text: String) -> Bool {
        return self.reduce(false, {$0 || $1.text == text})
    }
    
    /// Returns the tag which has the given text (if any, nil otherwise)
    func getTag(_ withText: String) -> Tag? {
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
    func getReadingTags(_ forRects: [NSRect], onPages: [Int]) -> [ReadingTag] {
        let rTags = self.flatMap({$0 as? ReadingTag})
        return rTags.filter({$0.containsNSRects(forRects, onPages: onPages)})
    }
}

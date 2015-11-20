//
//  ReadingRect.swift
//  PeyeDF
//
//  Created by Marco Filetti on 01/09/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

/// Represents a rect for DiMe usage ("replaces" NSRect in "external" communications)
public struct ReadingRect: Comparable, Equatable, Dictionariable {
    var pageIndex: NSNumber
    var rect: NSRect
    var readingClass: ReadingClass = ReadingClass.Unset
    var classSource: ClassSource = ClassSource.Unset
    var plainTextContent: String?
    var unixt: [NSNumber]
    var floating: Bool
    
    init(pageIndex: Int, origin: NSPoint, size: NSSize, readingClass: ReadingClass , classSource: ClassSource, pdfBase: MyPDFBase?) {
        let newUnixt = NSDate().unixTime
        self.unixt = [NSNumber]()
        self.unixt.append(newUnixt)
        
        self.floating = true
        
        self.pageIndex = pageIndex
        self.rect = NSRect(origin: origin, size: size)
        self.readingClass = readingClass
        self.classSource = classSource
        if let pdfb = pdfBase {
            self.plainTextContent = pdfb.stringForRect(self.rect, onPage: pageIndex)
        }
    }
    
    init(pageIndex: Int, rect: NSRect, readingClass: ReadingClass, classSource: ClassSource, pdfBase: MyPDFBase?) {
        let newUnixt = NSDate().unixTime
        self.unixt = [NSNumber]()
        self.unixt.append(newUnixt)
        
        self.floating = true
        
        self.pageIndex = pageIndex
        self.rect = rect
        self.readingClass = readingClass
        self.classSource = classSource
        if let pdfb = pdfBase {
            self.plainTextContent = pdfb.stringForRect(self.rect, onPage: pageIndex)
        }
    }
    
    init(pageIndex: Int, rect: NSRect, pdfBase: MyPDFBase?) {
        let newUnixt = NSDate().unixTime
        self.unixt = [NSNumber]()
        self.unixt.append(newUnixt)
        
        self.floating = true
        
        self.pageIndex = pageIndex
        self.rect = rect
        if let pdfb = pdfBase {
            self.plainTextContent = pdfb.stringForRect(self.rect, onPage: pageIndex)
        }
    }
    
    /// Creates a rect from a (dime-used) json object
    init(fromJson json: JSON) {
        self.unixt = json["unixt"].arrayObject! as! [NSNumber]
        self.floating = json["floating"].bool!
        
        let origin = NSPoint(x: json["origin"]["x"].doubleValue, y: json["origin"]["y"].doubleValue)
        let size = NSSize(width: json["size"]["width"].doubleValue, height: json["size"]["height"].doubleValue)
        self.rect = NSRect(origin: origin, size: size)
        self.readingClass = ReadingClass(rawValue: json["readingClass"].intValue)!
        self.classSource = ClassSource(rawValue: json["classSource"].intValue)!
        self.pageIndex = json["pageIndex"].intValue
        if let ptc = json["plainTextContent"].string {
            self.plainTextContent = ptc
        }
    }
    
    /// Unites these two rectangles and appends the unxtimes of the second rectangle to this rectangle.
    /// Uses a MyPDFBase instance to get the underlying plain text of united
    /// rect (if passed, otherwise simply appends the two strings.
    mutating func unite(otherRect: ReadingRect, pdfBase: MyPDFBase?) {
        var newRect = self
        newRect.floating = false
        
        // append times of second rect to this rect, after duplicate check
        for newt in otherRect.unixt {
            if !self.unixt.contains(newt) {
                newRect.unixt.append(newt)
            }
        }
        
        // unite underlying rects
        let unitedR = NSUnionRect(newRect.rect, otherRect.rect)
        newRect.rect = unitedR
        
        if let pdfb = pdfBase {
            if pdfb.document().getText() != nil {
                newRect.plainTextContent = pdfb.stringForReadingRect(newRect)
            }
        } else {
            if newRect.plainTextContent != nil {
                if otherRect.plainTextContent != nil {
                    // if they both have text, unite them using MyPDFBase instance
                    // if no pdfBase is given, simply append the second string to this one
                    newRect.plainTextContent! += otherRect.plainTextContent!
                }
            } else {
                if otherRect.plainTextContent != nil {
                    newRect.plainTextContent = otherRect.plainTextContent!
                }
            }
        }
        
        self = newRect
    }
    
    /// Shrinks the underlying rectangle using another rectangle
    func subtractRect(rhs: ReadingRect, pdfBase: MyPDFBase?) -> [ReadingRect] {
        let result = self.rect.subtractRect(rhs.rect)
        var retVal = [ReadingRect]()
        for rect in result {
            retVal.append(ReadingRect(pageIndex: pageIndex.integerValue, rect: rect, readingClass: readingClass, classSource: classSource, pdfBase: pdfBase))
        }
        return retVal
    }
    
    /// Returns true if these two rectangles intersect and are on the same page.
    /// Traps with fatalError if they are not the same class.
    func intersects(otherRect: ReadingRect) -> Bool {
        if self.pageIndex != otherRect.pageIndex {
            return false
        }
        if self.readingClass != otherRect.readingClass {
            fatalError("Two rects of different classes are being compared for intersection")
        }
        return NSIntersectsRect(self.rect, otherRect.rect)
    }
    
    mutating func addUnixt(newUnixt: NSNumber) {
        self.unixt.append(newUnixt)
    }
    
    mutating func setClass(newClass: ReadingClass) {
        self.readingClass = newClass
    }
    
    mutating func setClassSource(newClassSource: ClassSource) {
        self.classSource = newClassSource
    }
    
    /// Returns itself in a dict of strings, matching DiMe's Rect class
    func getDict() -> [String : AnyObject] {
        var retDict = [String: AnyObject]()
        retDict["pageIndex"] = self.pageIndex
        retDict["unixt"] = self.unixt
        retDict["floating"] = self.floating
        retDict["origin"] = self.rect.origin.getDict()
        retDict["size"] = self.rect.size.getDict()
        retDict["readingClass"] = self.readingClass.rawValue
        retDict["classSource"] = self.classSource.rawValue
        if let ptc = plainTextContent {
            retDict["plainTextContent"] = ptc
        }
        return retDict
    }
}

/// ReadingRects are equal if all their properties are equal
public func == (lhs: ReadingRect, rhs: ReadingRect) -> Bool {
    return lhs.pageIndex == rhs.pageIndex &&
           lhs.rect == rhs.rect &&
           lhs.readingClass == rhs.readingClass &&
           lhs.unixt == rhs.unixt &&
           lhs.classSource == rhs.classSource
}

/// To allow sorting arrays of readingrects (when uniting them, for example),
/// ReadingRects can be compared based on the position of their rectangles.
/// This function traps if they are not on the same page or if they are not the same class! (fatalError)
/// See also: public func < (lhs: NSRect, rhs: NSRect) 
public func < (lhs: ReadingRect, rhs: ReadingRect) -> Bool {
    if lhs.readingClass != rhs.readingClass {
        fatalError("Two rects of a different class are being compared")
    }
    
    if lhs.pageIndex != rhs.pageIndex {
        fatalError("Two rects on a different page are being compared")
    }
    
    let constant: CGFloat = PeyeConstants.rectHorizontalTolerance
    let lrect = lhs.rect
    let rrect = rhs.rect
    if withinRange(lrect.origin.x, rhs: rrect.origin.x, range: constant) {
        return lrect.origin.y > rrect.origin.y
    } else {
        return lrect.origin.x < rrect.origin.x
    }
}
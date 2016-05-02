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

/// Represents a rect for DiMe usage ("replaces" NSRect in "external" communications)
public struct ReadingRect: Comparable, Equatable, Dictionariable, NearlyEquatable {
    
    var pageIndex: NSNumber
    var rect: NSRect
    var readingClass: ReadingClass = ReadingClass.Unset
    var classSource: ClassSource = ClassSource.Unset
    var plainTextContent: String?
    var unixt: [NSNumber]
    var floating: Bool
    var scaleFactor: NSNumber
    var screenDistance: NSNumber
    var attnVal: NSNumber?
    
    init(pageIndex: Int, origin: NSPoint, size: NSSize, readingClass: ReadingClass, classSource: ClassSource, pdfBase: MyPDFBase?) {
        let newUnixt = NSDate().unixTime
        self.screenDistance = MidasManager.sharedInstance.lastValidDistance
        self.unixt = [NSNumber]()
        self.unixt.append(newUnixt)
        
        self.floating = true
        
        self.pageIndex = pageIndex
        self.rect = NSRect(origin: origin, size: size)
        self.readingClass = readingClass
        self.classSource = classSource
        if let pdfb = pdfBase {
            self.plainTextContent = pdfb.stringForRect(self.rect, onPage: pageIndex)
            self.scaleFactor = pdfb.scaleFactor()
        } else {
            self.scaleFactor = -1
        }
    }
    
    init(pageIndex: Int, rect: NSRect, readingClass: ReadingClass, classSource: ClassSource, pdfBase: MyPDFBase?) {
        let newUnixt = NSDate().unixTime
        self.screenDistance = MidasManager.sharedInstance.lastValidDistance
        self.unixt = [NSNumber]()
        self.unixt.append(newUnixt)
        
        self.floating = true
        
        self.pageIndex = pageIndex
        self.rect = rect
        self.readingClass = readingClass
        self.classSource = classSource
        if let pdfb = pdfBase {
            self.plainTextContent = pdfb.stringForRect(self.rect, onPage: pageIndex)
            self.scaleFactor = pdfb.scaleFactor()
        } else {
            self.scaleFactor = -1
        }
    }
    
    init(pageIndex: Int, rect: NSRect, pdfBase: MyPDFBase?) {
        self.screenDistance = MidasManager.sharedInstance.lastValidDistance
        let newUnixt = NSDate().unixTime
        self.unixt = [NSNumber]()
        self.unixt.append(newUnixt)
        
        self.floating = true
        
        self.pageIndex = pageIndex
        self.rect = rect
        if let pdfb = pdfBase {
            self.plainTextContent = pdfb.stringForRect(self.rect, onPage: pageIndex)
            self.scaleFactor = pdfb.scaleFactor()
        } else {
            self.scaleFactor = -1
        }
    }
    
    init(fromEyeRect eyeRect: EyeRectangle, readingClass: ReadingClass) {
        self.unixt = [eyeRect.unixt as NSNumber]
        self.rect = NSRect(origin: eyeRect.origin, size: eyeRect.size)
        self.floating = false
        self.plainTextContent = eyeRect.plainTextContent
        self.readingClass = readingClass
        self.classSource = ClassSource.ML
        self.pageIndex = eyeRect.pageIndex
        self.scaleFactor = eyeRect.scaleFactor
        self.screenDistance = eyeRect.screenDistance
        self.attnVal = eyeRect.attnVal
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
        self.scaleFactor = json["scaleFactor"].doubleValue
        if let ptc = json["plainTextContent"].string {
            self.plainTextContent = ptc
        }
        self.screenDistance = json["screenDistance"].double ?? 600.0
        self.attnVal = json["attnVal"].double
    }
    
    /// Unites these two rectangles and appends the unxtimes of the second rectangle to this rectangle.
    /// Uses a MyPDFBase instance to get the underlying plain text of united
    /// rect (if passed, otherwise simply appends the two strings.
    mutating func unite(otherRect: ReadingRect, pdfBase: MyPDFBase?) {
        var newRect = self
        newRect.floating = false
        
        // invalidate scalefactor if the two rects have different values
        if newRect.scaleFactor != otherRect.scaleFactor {
            newRect.scaleFactor = -1
        }
        
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
            if pdfb.containsPlainText {
                newRect.plainTextContent = pdfb.stringForRect(newRect)
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
        retDict["scaleFactor"] = self.scaleFactor
        retDict["screenDistance"] = self.screenDistance
        if let av = self.attnVal {
            retDict["attnVal"] = av
        }
        if let ptc = plainTextContent {
            retDict["plainTextContent"] = ptc
        }
        return retDict
    }
    
    func nearlyEqual(other: ReadingRect) -> Bool {
        return self.pageIndex == other.pageIndex &&
               self.rect.nearlyEqual(other.rect) &&
               self.readingClass == other.readingClass &&
               self.classSource == other.classSource
     }
}

/// ReadingRects are equal if all their properties are equal
public func == (lhs: ReadingRect, rhs: ReadingRect) -> Bool {
    return lhs.pageIndex == rhs.pageIndex &&
           lhs.rect == rhs.rect &&
           lhs.readingClass == rhs.readingClass &&
           lhs.classSource == rhs.classSource &&
           lhs.scaleFactor == rhs.scaleFactor
}

/// To allow sorting arrays of readingrects (when uniting them, for example),
/// ReadingRects can be compared based on the position of their rectangles.
/// This function traps if they are not the same class! (fatalError).
/// See also: public func < (lhs: NSRect, rhs: NSRect)
public func < (lhs: ReadingRect, rhs: ReadingRect) -> Bool {
    if lhs.readingClass != rhs.readingClass {
        fatalError("Two rects of a different class are being compared")
    }
    
    let constant: CGFloat = PeyeConstants.rectHorizontalTolerance
    let lrect = lhs.rect
    let rrect = rhs.rect
    
    // first compare page
    if lhs.pageIndex != rhs.pageIndex {
        return lhs.pageIndex < rhs.pageIndex
    }
    
    // then compare position on page
    if withinRange(lrect.origin.x, rhs: rrect.origin.x, range: constant) {
        return lrect.origin.y > rrect.origin.y
    } else {
        return lrect.origin.x < rrect.origin.x
    }
}
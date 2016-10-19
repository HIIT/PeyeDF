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
    
    var pageIndex: Int
    var rect: NSRect
    var readingClass: ReadingClass = ReadingClass.unset
    var classSource: ClassSource = ClassSource.unset
    var plainTextContent: String?
    var unixt: [Int]
    var floating: Bool
    var scaleFactor: Double
    var screenDistance: Double
    var attnVal: Double?
    
    /// Rects which are fetched from DiMe or json are not "new".
    /// This is used so that only newly created rects are sent in summary events
    /// after reading a document.
    fileprivate(set) var new: Bool = true
    
    init(pageIndex: Int, origin: NSPoint, size: NSSize, readingClass: ReadingClass, classSource: ClassSource, pdfBase: PDFBase?) {
        let newUnixt = Date().unixTime
        self.screenDistance = Double(AppSingleton.userDistance)
        self.unixt = [Int]()
        self.unixt.append(newUnixt)
        
        self.floating = true
        
        self.pageIndex = pageIndex
        self.rect = NSRect(origin: origin, size: size)
        self.readingClass = readingClass
        self.classSource = classSource
        if let pdfb = pdfBase {
            self.plainTextContent = pdfb.stringForRect(self.rect, onPage: pageIndex)
            self.scaleFactor = Double(pdfb.scaleFactor)
        } else {
            self.scaleFactor = -1
        }
    }
    
    init(pageIndex: Int, rect: NSRect, readingClass: ReadingClass, classSource: ClassSource, pdfBase: PDFBase?) {
        let newUnixt = Date().unixTime
        self.screenDistance = Double(AppSingleton.userDistance)
        self.unixt = [Int]()
        self.unixt.append(newUnixt)
        
        self.floating = true
        
        self.pageIndex = pageIndex
        self.rect = rect
        self.readingClass = readingClass
        self.classSource = classSource
        if let pdfb = pdfBase {
            self.plainTextContent = pdfb.stringForRect(self.rect, onPage: pageIndex)
            self.scaleFactor = Double(pdfb.scaleFactor)
        } else {
            self.scaleFactor = -1
        }
    }
    
    init(pageIndex: Int, rect: NSRect, pdfBase: PDFBase?) {
        self.screenDistance = Double(AppSingleton.EyeTracker?.lastValidDistance ?? 800.0)
        let newUnixt = Date().unixTime
        self.unixt = [Int]()
        self.unixt.append(newUnixt)
        
        self.floating = true
        
        self.pageIndex = pageIndex
        self.rect = rect
        if let pdfb = pdfBase {
            self.plainTextContent = pdfb.stringForRect(self.rect, onPage: pageIndex)
            self.scaleFactor = Double(pdfb.scaleFactor)
        } else {
            self.scaleFactor = -1
        }
    }
    
    init(fromEyeRect eyeRect: EyeRectangle, readingClass: ReadingClass) {
        self.unixt = [eyeRect.unixt]
        self.rect = NSRect(origin: eyeRect.origin, size: eyeRect.size)
        self.floating = false
        self.plainTextContent = eyeRect.plainTextContent
        self.readingClass = readingClass
        self.classSource = ClassSource.ml
        self.pageIndex = eyeRect.pageIndex
        self.scaleFactor = eyeRect.scaleFactor
        self.screenDistance = eyeRect.screenDistance
        self.attnVal = eyeRect.attnVal
    }
    
    /// Creates a rect from a (dime-used) json object
    init(fromJson json: JSON) {
        self.unixt = json["unixt"].arrayObject! as! [Int]
        self.floating = json["floating"].bool!
        
        self.new = false
        
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
    /// Uses a PDFBase instance to get the underlying plain text of united
    /// rect (if passed, otherwise simply appends the two strings.
    mutating func unite(_ otherRect: ReadingRect, pdfBase: PDFBase?) {
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
                    // if they both have text, unite them using PDFBase instance
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
    func subtractRect(_ rhs: ReadingRect, pdfBase: PDFBase?) -> [ReadingRect] {
        let result = self.rect.subtractRect(rhs.rect)
        var retVal = [ReadingRect]()
        for rect in result {
            retVal.append(ReadingRect(pageIndex: pageIndex, rect: rect, readingClass: readingClass, classSource: classSource, pdfBase: pdfBase))
        }
        return retVal
    }
    
    /// Returns true if these two rectangles intersect and are on the same page.
    /// Traps with fatalError if they are not the same class.
    func intersects(_ otherRect: ReadingRect) -> Bool {
        if self.pageIndex != otherRect.pageIndex {
            return false
        }
        if self.readingClass != otherRect.readingClass {
            fatalError("Two rects of different classes are being compared for intersection")
        }
        return NSIntersectsRect(self.rect, otherRect.rect)
    }
    
    mutating func addUnixt(_ newUnixt: Int) {
        self.unixt.append(newUnixt)
    }
    
    mutating func setClass(_ newClass: ReadingClass) {
        self.readingClass = newClass
    }
    
    mutating func setClassSource(_ newClassSource: ClassSource) {
        self.classSource = newClassSource
    }
    
    /// Returns itself in a dict of strings, matching DiMe's Rect class
    func getDict() -> [String : Any] {
        var retDict = [String: Any]()
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
    
    func nearlyEqual(_ other: ReadingRect) -> Bool {
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
    
    let lrect = lhs.rect
    let rrect = rhs.rect
    
    // first compare page
    if lhs.pageIndex != rhs.pageIndex {
        return lhs.pageIndex < rhs.pageIndex
    }
    
    // then compare position on page
    if lrect.horizontalOverlap(rrect) {
        return lrect.origin.y > rrect.origin.y
    } else {
        return lrect.origin.x < rrect.origin.x
    }
}

// MARK: - PDFAnnotation-related

extension ReadingRect {
    
    
    /// Create a ReadingRect from a single point, and hence the paragraph/subparagraph related to it (for quick, or "click" annotations)
    /// should be marked as somehow important
    ///
    /// - returns: A ReadingRect representing the rectangle that was created, on which page it was created and what importance, nil if the operation failed
    init?(fromPoint locationInView: NSPoint, pdfBase: PDFBase, importance: ReadingClass) {
        
        // Page we're on.
        let activePage = pdfBase.page(for: locationInView, nearest: true)
        
        // Index for current page
        let pageIndex = pdfBase.document!.index(for: activePage!)
        
        // Get location in "page space".
        let pagePoint = pdfBase.convert(locationInView, to: activePage!)
        
        // Convert point to rect, if possible
        guard let markRect = pdfBase.pointToParagraphRect(pagePoint, forPage: activePage!) else {
            return nil
        }
        
        if importance != ReadingClass.low && importance != ReadingClass.medium && importance != ReadingClass.high {
            let exception = NSException(name: NSExceptionName(rawValue: "Not implemented"), reason: "Unsupported reading class for annotation", userInfo: nil)
            exception.raise()
        }
        
        // Create new reading rect using given parameters and put in history for dime submission
        self = ReadingRect(pageIndex: pageIndex, rect: markRect, readingClass: importance, classSource: .click, pdfBase: pdfBase)
        
    }
    
    /// Returns a set of ReadingRects from a selection made in a PDF document.
    /// Returns nil if operation failed.
    static func makeReadingRects(fromSelectionIn pdfBase: PDFBase, importance: ReadingClass) -> [ReadingRect]? {
        guard let selection = pdfBase.currentSelection else {
            return nil
        }
        
        let (rects, idxs) = pdfBase.getLineRects(selection)
        
        guard rects.count > 0 else {
            return nil
        }

        var rRects = [ReadingRect]()
        for i in 0..<rects.count {
            rRects.append(ReadingRect(pageIndex: idxs[i], rect: rects[i], readingClass: importance, classSource: .manualSelection, pdfBase: pdfBase))
        }
        return rRects
    }
    
    /// Returns an NSRect corresponding to the annotation shown for a reading rectangle representing to a mark (shown slightly on the left of a given paragraph or as underline).
    ///
    /// - parameter markRect: The rectangle corresponding to the mark
    /// - returns: A rectangle representing the annotation
    var annotationRect: NSRect { get {
        switch self.classSource {
        case .click, .ml:
            // if this is for a quick annotation, show on the left of paragraph
            // also used for machine learning
            let markRect = self.rect
            let lineThickness = UserDefaults.standard.object(forKey: PeyeConstants.prefAnnotationLineThickness) as! CGFloat
            let newRect_x = markRect.origin.x - PeyeConstants.quickAnnotationDistance
            let newRect_y = markRect.origin.y
            let newRect_height = markRect.height
            let newRect_width = lineThickness
            return NSRect(x: newRect_x, y: newRect_y, width: newRect_width, height: newRect_height)
        case .manualSelection:
            // if this is for a manual selection annotation show below (underline)
            let markRect = self.rect
            let lineThickness = UserDefaults.standard.object(forKey: PeyeConstants.prefAnnotationLineThickness) as! CGFloat
            let newRect_x = markRect.origin.x
            let newRect_y = markRect.origin.y - PeyeConstants.selectionAnnotationDistance
            let newRect_height = lineThickness
            let newRect_width = markRect.width
            return NSRect(x: newRect_x, y: newRect_y, width: newRect_width, height: newRect_height)
        default:
            // for all other cases the rect == annotation
            return self.rect
        }
    } }
}

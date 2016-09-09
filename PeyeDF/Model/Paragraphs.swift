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

// This source file contains classes helpful in storing paragraph (of various classes of "importance") in PDF documents

import Foundation

/// Represents all markings in a given PDF Document. Essentially, it uses PDF Page indices to index all rectangles (paragraphs) of a given importance
struct PDFMarkings {
    
    /// All rectangles (markings) for the given document.
    private var allRects = [ReadingRect]()
    
    /// Reference to PDFBase is used to get text within reading rects and scaleFactors
    unowned let pdfBase: PDFBase
    
    /// Create an empty state with markings of a given source using the given pdfBase to get text
    init(pdfBase: PDFBase) {
        self.pdfBase = pdfBase
    }
    
    // MARK: - Accessors
    
    /// Get overall count of rectangles
    func getCount() -> Int {
        return allRects.count
    }
    
    /// Return all rectangles in an array of ReadingRects
    func getAllReadingRects() -> [ReadingRect] {
        return allRects
    }
    
    /// Return all rectangles made from the given source
    func getAll(forSource source: ClassSource) -> [ReadingRect] {
        return allRects.filter({$0.classSource == source})
    }
    
    /// Return all rectangles made from the given source, of the given class
    func get(onlySource source: ClassSource, ofClass: ReadingClass) -> [ReadingRect] {
        return allRects.filter({$0.classSource == source && $0.readingClass == ofClass})
    }
    
    /// Returns all rectangles for a given class
    func get(onlyClass theClass: ReadingClass) -> [ReadingRect] {
        return allRects.filter({$0.readingClass == theClass})
    }
    
    /// Returns all rectangles for a given class, on a given page
    func get(ofClass theClass: ReadingClass, forPage: Int) -> [ReadingRect] {
        return allRects.filter({$0.readingClass == theClass && $0.pageIndex.integerValue == forPage})
    }
    
    // MARK: - Mutators
    
    /// Add a rect of the given class to the given page. Does not add
    /// duplicates.
    mutating func addRect(rect: NSRect, ofClass: ReadingClass, withSource: ClassSource, forPage: Int) {
        let newRect = ReadingRect(pageIndex: forPage, rect: rect, readingClass: ofClass, classSource: withSource, pdfBase: pdfBase)
        if !(allRects.contains(newRect)) {
            allRects.append(newRect)
        }
    }
    
    /// Add a reading rect to the array. Does not add duplicates. Traps if added rect's source does not match
    /// this instance's source
    mutating func addRect(readingRect: ReadingRect) {
        if !(allRects.contains(readingRect)) {
            allRects.append(readingRect)
        }
    }
    
    /// Sets rects of a given class to the given dictionary.
    mutating func set(theClass: ReadingClass, _ rects: [ReadingRect]) {
        // remove all rects of the given class
        allRects = allRects.filter({$0.readingClass != theClass})
        for newRect in rects {
            if newRect.readingClass != theClass {
                AppSingleton.log.error("Added reading rect class does not match requested class")
            }
            if !allRects.contains(newRect) {
                allRects.append(newRect)
            }
        }
    }
    
    /// Set all rect with the given source to a new list of rects.
    mutating func setAll(forSource source: ClassSource, newRects: [ReadingRect]) {
        allRects = allRects.filter({$0.classSource != source})
        for rect in newRects {
            if rect.classSource != source {
                AppSingleton.log.error("Passed rect with source \(rect.classSource) does not match \(source)")
            } else {
                allRects.append(rect)
            }
        }
    }
    
    /// Set all underlying rects to the given array
    mutating func setAll(newRects: [ReadingRect]) {
        self.allRects = newRects
    }
    
    /// "Flatten" all "relevant" rectangles so that:
    ///
    /// - No rectangles overlap
    /// - Rectangles of a lower class are overwritten by rectangles of a higher class.
    ///   For example, we show critical rectangles first, then interesting rectangles, then read ones at the bottom.
    
    ///   This is because critical rectangles are assumed to be both interesting and read.
    mutating func flattenRectangles_relevance() {
        // "relevance" classes in order of importance: Critical, Interesting, Read
        uniteRectangles(.High)
        uniteRectangles(.Medium)
        uniteRectangles(.Low)
        // Subtract critical (high) rects from interesting (medium) and read (low) rects
        subtractRectsOfClass(minuend: .Medium, subtrahend: .High)
        subtractRectsOfClass(minuend: .Low, subtrahend: .High)
        
        uniteRectangles(.Medium)
        // Subtract (remaining) interesting rects from read rects
        subtractRectsOfClass(minuend: .Low, subtrahend: .Medium)
        
        uniteRectangles(.Low)
    }
    
    /// "Flatten" all "relevant" rectangles so that:
    ///
    /// - Intersections of low and medium rects are "upgraded" to rects of high importance (different from flattenRectangles_relevance)
    /// - No rectangles overlap
    /// - Rectangles of a lower class are overwritten by rectangles of a higher class.
    ///   For example, we show critical rectangles first, then interesting rectangles, then read ones at the bottom.
    
    ///   This is because critical rectangles are assumed to be both interesting and read.
    mutating func flattenRectangles_intersectToHigh() {
        // "relevance" classes in order of importance: Critical, Interesting, Read
        uniteRectangles(.High)
        uniteRectangles(.Medium)
        uniteRectangles(.Low)
        
        // - start intersection (low and medium class interesecting sections will result in high class rect)
        let mediumRects = allRects.filter({$0.readingClass == .Medium})
        for mRect in mediumRects {
            let lowRects = allRects.filter({$0.readingClass == .Low && $0.pageIndex == mRect.pageIndex})
            for lRect in lowRects {
                let intersection = NSIntersectionRect(mRect.rect, lRect.rect)
                if !NSIsEmptyRect(intersection) {
                    allRects.append(ReadingRect(pageIndex: mRect.pageIndex as Int, rect: intersection, readingClass: .High, classSource: mRect.classSource, pdfBase: pdfBase))
                }
            }
        }
        
        uniteRectangles(.High)
        // - end intersection
        
        // Subtract critical (high) rects from interesting (medium) and read (low) rects
        subtractRectsOfClass(minuend: .Medium, subtrahend: .High)
        subtractRectsOfClass(minuend: .Low, subtrahend: .High)
        
        uniteRectangles(.Medium)
        // Subtract (remaining) interesting rects from read rects
        subtractRectsOfClass(minuend: .Low, subtrahend: .Medium)
        
        uniteRectangles(.Low)
    }
    
    /// Unite all floating eye rectangles into bigger rectangles that enclose them
    mutating func flattenRectangles_eye() {
        uniteRectangles(.Paragraph)
    }
    
    /// Unite all rectangles of the given class
    mutating func uniteRectangles(ofClass: ReadingClass) {
        // create set of all possible page indices
        var pis = Set<Int>()
        for rrect in allRects {
            if rrect.readingClass == ofClass {
                pis.insert(rrect.pageIndex.integerValue)
            }
        }
        for page in pis {
            let rectsToUnite = allRects.filter({$0.readingClass == ofClass && $0.pageIndex == page})
            allRects = allRects.filter({!($0.readingClass == ofClass && $0.pageIndex == page)})
            let unitedRects = uniteCollidingRects(forPage: page, inputArray: rectsToUnite)
            allRects.appendContentsOf(unitedRects)
        }
    }
    
    /// Subtracts all rect of a given class from all rects of another class
    ///
    /// - parameter minuend: The class of rectangles to subtract from
    /// - parameter subtrahend: The class of rectangles that will be subtracted
    mutating func subtractRectsOfClass(minuend lhs: ReadingClass, subtrahend rhs: ReadingClass) {
        // create set of all possible page indices
        var pis = Set<Int>()
        for rrect in allRects {
            if rrect.readingClass == lhs || rrect.readingClass == rhs {
                pis.insert(rrect.pageIndex.integerValue)
            }
        }
        for page in pis {
            // only continue if there is something to subtract in rhs
            let subtrahends = allRects.filter({$0.readingClass == rhs && $0.pageIndex == page})
            if subtrahends.count > 0 {
                // assign minuends and remove them from allRects
                let minuends = allRects.filter({$0.readingClass == lhs && $0.pageIndex == page})
                allRects = allRects.filter({!($0.readingClass == lhs && $0.pageIndex == page)})
                let subtractedRects = subtractRectangles(forPage: page, minuends: minuends, subtrahends: subtrahends)
                // add result of subtraction back to allRects
                allRects.appendContentsOf(subtractedRects)
            }
        }
    }
    
    /// Calculate proportion of Read, Interesting and Critical markings for the given parameters.
    /// This is done by calculating the total area of each page and multiplying it by a constant.
    /// All rectangles (which will be united) are then cycled and the area of each is subtracted
    /// to calculate a proportion. Returns nil if no pdfBase is connected.
    mutating func calculateProportions_relevance() -> (proportionRead: Double, proportionInteresting: Double, proportionCritical: Double)? {
        flattenRectangles_relevance()
        var totalSurface = 0.0
        var readSurface = 0.0
        var interestingSurface = 0.0
        var criticalSurface = 0.0
        for pageI in 0 ..< pdfBase.document().pageCount() {
            let thePage = pdfBase.document().pageAtIndex(pageI)
            let pageRect = pdfBase.getPageRect(thePage)
            let pageSurface = Double(pageRect.size.height * pageRect.size.width)
            totalSurface += pageSurface
            for rect in get(ofClass: .Low, forPage: pageI) {
                readSurface += Double(rect.rect.size.height * rect.rect.size.width)
            }
            for rect in get(ofClass: .Medium, forPage: pageI) {
                interestingSurface += Double(rect.rect.size.height * rect.rect.size.width)
            }
            for rect in get(ofClass: .High, forPage: pageI) {
                criticalSurface += Double(rect.rect.size.height * rect.rect.size.width)
            }
        }
        totalSurface *= PeyeConstants.pageAreaMultiplier
        let proportionRead = readSurface / totalSurface
        let proportionInteresting = interestingSurface / totalSurface
        let proportionCritical = criticalSurface / totalSurface
        return (proportionRead: proportionRead, proportionInteresting: proportionInteresting, proportionCritical: proportionCritical)
    }
    
    /// Calculate proportion of gazed-at united rectangles for the markings passed as a parameter.
    /// This is done by calculating the total area of each page and multiplying it by a constant.
    /// All rectangles (which will be united) are then cycled and the area of each is subtracted
    /// to calculate a proportion. Returns 0 if no pdfBase is connected.
    mutating func calculateProportion_smi() -> Double {
        flattenRectangles_eye()
        var totalSurface = 0.0
        var gazedSurface = 0.0
        for pageI in 0..<pdfBase.document().pageCount() {
            let thePage = pdfBase.document().pageAtIndex(pageI)
            let pageRect = pdfBase.getPageRect(thePage)
            let pageSurface = Double(pageRect.size.height * pageRect.size.width)
            totalSurface += pageSurface
            for rect in get(onlyClass: .Paragraph) {
                gazedSurface += Double(rect.rect.size.height * rect.rect.size.width)
            }
        }
        totalSurface *= PeyeConstants.pageAreaMultiplier
        let proportionGazed = gazedSurface / totalSurface
        return proportionGazed
    }
    

    /// Given an array of reading rectangles, return a sorted version of the array
    /// (sorted so that elements coming first should have been read first in western order)
    /// with the colliding rectangles united (two rects collide when their intersection is not zero).
    func uniteCollidingRects(forPage forPage: Int, inputArray: [ReadingRect]) -> [ReadingRect] {
        var ary = inputArray
        ary.sortInPlace()
        var i = 0
        while i + 1 < ary.count {
            if ary[i].pageIndex != forPage {
                fatalError("Page indices for rects that have to be united do not match")
            }
            if NSIntersectsRect(ary[i].rect, ary[i+1].rect) {
                ary[i].unite(ary[i+1], pdfBase: pdfBase)
                ary.removeAtIndex(i+1)
            } else {
                i += 1
            }
        }
        return ary
    }

    /// Given two sorted arrays of rectangles, assumed to be on the same page,
    /// subtract them (minuend-subtrahend). The subtrahend stays the same and
    /// is not returned. Returned is an array of minuends.
    ///
    /// - parameter minuends: The array of rectangles from which the other will be subtracted (lhs)
    /// - parameter subtrahends: The array of rectangles that will be subtracted from minuends (rhs)
    /// - returns: An array of rectangles which is the result of minuends - subtrahends
    func subtractRectangles(forPage forPage: Int, minuends: [ReadingRect], subtrahends: [ReadingRect]) -> [ReadingRect] {
        var minuends = minuends
        var collidingRects: [(lhsRect: ReadingRect, rhsRect: ReadingRect)] // tuples with minuend rect and subtrahend rects which intersect (must be on the same page)
        
        // return the same result if there is nothing to subtract from / to
        if minuends.count == 0 || subtrahends.count == 0 {
            return minuends
        }
        
        // repeat the procedure until no more collisions are found
        // do this a maximum number of times, if this exceeds report an error
        let maxLoops = 50
        var loops = 0
        var collisions = false
        var result: [ReadingRect]
        repeat {
            collidingRects = []
            
            var i = 0
            result = minuends
            while i < result.count {
                let minuendRect = result[i]
                for subtrahendRect in subtrahends {
                    if NSIntersectsRect(minuendRect.rect, subtrahendRect.rect) {
                        collidingRects.append((lhsRect: minuendRect, rhsRect: subtrahendRect))
                        result.removeAtIndex(i)
                        break
                    }
                }
                i += 1
            }
            
            collisions = !collidingRects.isEmpty
            
            for (minuendRect, subtrahendRect) in collidingRects {
                result.appendContentsOf(minuendRect.subtractRect(subtrahendRect, pdfBase: pdfBase))
            }
            
            minuends = result
            
            loops += 1
        } while collisions && loops < maxLoops
        if loops >= maxLoops {
            AppSingleton.log.error("Loops exceeded maximum loops, check subtraction algo")
        }
        return result
    }
    
}

/// This class represents a "marking state", that is a selection of importance rectangles and the last rectangle and
/// last page that were edited. It is used to store states in undo operations.
class PDFMarkingsState: NSObject {
    /// All rectangles, prior to addition / deletion
    var rectState: [ReadingRect]
    /// The rectangle on which the last modification was made.
    /// If nil, assumes that this is change encompasses all rectangles
    /// (this means that the whole screen, instead of a section, has to be refreshed)
    private var lastRect: ReadingRect?
    
    init(oldState: [ReadingRect]) {
        self.rectState = oldState
    }
    
    /// Sets the last rectangle (and on which page) that was added / removed
    func setLastRect(lastRect: ReadingRect) {
        self.lastRect = lastRect
    }
    
    /// Returns the last rectangle. If the change was not related to a single rect
    /// (e.g many were set at once) this should return nil.
    func getLastRect() -> ReadingRect? {
        return lastRect
    }
}

// MARK: - Rectangle reading classes

/// How important is a paragraph
public enum ReadingClass: Int {
    case Unset = 0
    case Tag = 1  // note: this is treated separately ("tags" are not "marks")
    case Viewport = 10
    case Paragraph = 15
    case Low = 20  // known as "read" in dime
    case FoundString = 25
    case Medium = 30  // known as "critical" in dime
    case High = 40  // known as "high" in dime
}

/// What decided that a paragraph is important
public enum ClassSource: Int {
    case Unset = 0
    case Viewport = 1
    case Click = 2
    case SMI = 3
    case ML = 4
    case Search = 5
    case LocalPeer = 6  // TODO: `Peer`s are not currently considered in DiMe
    case NetworkPeer = 7
}

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
    fileprivate var allRects = [ReadingRect]()
    
    /// All circles for the given document.
    var circles = [Circle]()
    
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
    
    /// Return all rectangles made from any of the given sources
    func getAll(forSources sources: [ClassSource]) -> [ReadingRect] {
        return allRects.filter({ rect in
            sources.reduce(false, {$0 || rect.classSource == $1})
        })
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
        return allRects.filter({$0.readingClass == theClass && $0.pageIndex == forPage})
    }
    
    // MARK: - Mutators
    
    /// Add a rect of the given class to the given page. Does not add
    /// duplicates.
    mutating func addRect(_ rect: NSRect, ofClass: ReadingClass, withSource: ClassSource, forPage: Int) {
        let newRect = ReadingRect(pageIndex: forPage, rect: rect, readingClass: ofClass, classSource: withSource, pdfBase: pdfBase)
        if !(allRects.contains(newRect)) {
            allRects.append(newRect)
        }
    }
    
    /// Add a reading rect to the array. Does not add duplicates. Traps if added rect's source does not match
    /// this instance's source
    mutating func addRect(_ readingRect: ReadingRect) {
        if !(allRects.contains(readingRect)) {
            allRects.append(readingRect)
        }
    }
    
    /// Sets rects of a given class to the given dictionary.
    mutating func set(_ theClass: ReadingClass, _ rects: [ReadingRect]) {
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

    /// Set all rect with the given sources to a new list of rects (i.e. remove them and replace them with newRects).
    mutating func setAll(forSources sources: [ClassSource], newRects: [ReadingRect]) {
        allRects = allRects.filter({rect in
            sources.reduce(true, {$0 && rect.classSource != $1})
        })
        for rect in newRects {
            if !(sources.reduce(false, {$0 || rect.classSource == $1})) {
                AppSingleton.log.error("Passed rect with source \(rect.classSource) does not match any of the given sources (\(sources))")
            } else {
                allRects.append(rect)
            }
        }
    }

    /// Set all underlying rects to the given array
    mutating func setAll(_ newRects: [ReadingRect]) {
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
        
        // remove lower-relevance rects which are completely enclosed by other rects
        let topRects = allRects.filter({$0.readingClass == .high})
        let mediumRects = allRects.filter({$0.readingClass == .medium})
        
        // remove very low when enclosed by medium and high
        allRects = allRects.filter() {
            rect in
            switch rect.readingClass {
            case .high:
                return true
            case .medium:
                let enclosedByTopRect = topRects.reduce(false, {$0 || ($1.pageIndex == rect.pageIndex && $1.rect.contains(rect.rect))})
                return !enclosedByTopRect
            case .low:
                let enclosedByTopRect = topRects.reduce(false, {$0 || ($1.pageIndex == rect.pageIndex && $1.rect.contains(rect.rect))})
                let enclosedByMediumRect = mediumRects.reduce(false, {$0 || ($1.pageIndex == rect.pageIndex && $1.rect.contains(rect.rect))})
                return !enclosedByTopRect && !enclosedByMediumRect
            default:
                return true
            }
        }
        
        // operate on quick marks and manual selection marks separately
        let sourcesOfInterest: [ClassSource] = [.click, .manualSelection]
        for source in sourcesOfInterest {
            uniteRectangles(.high, onlySource: source)
            uniteRectangles(.medium, onlySource: source)
            uniteRectangles(.low, onlySource: source)
            // Subtract critical (high) rects from interesting (medium) and read (low) rects
            subtractRectsOfClass(minuend: .medium, subtrahend: .high, onlySource: source)
            subtractRectsOfClass(minuend: .low, subtrahend: .high, onlySource: source)
            
            uniteRectangles(.medium, onlySource: source)
            // Subtract (remaining) interesting rects from read rects
            subtractRectsOfClass(minuend: .low, subtrahend: .medium, onlySource: source)
            
            uniteRectangles(.low, onlySource: source)
        }
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
        uniteRectangles(.high, onlySource: .localPeer)
        uniteRectangles(.medium, onlySource: .localPeer)
        uniteRectangles(.low, onlySource: .localPeer)
        
        // - start intersection (low and medium class interesecting sections will result in high class rect)
        let mediumRects = allRects.filter({$0.readingClass == .medium && $0.classSource == .localPeer})
        for mRect in mediumRects {
            let lowRects = allRects.filter({$0.readingClass == .low && $0.pageIndex == mRect.pageIndex && $0.classSource == .localPeer})
            for lRect in lowRects {
                let intersection = NSIntersectionRect(mRect.rect, lRect.rect)
                if !NSIsEmptyRect(intersection) {
                    allRects.append(ReadingRect(pageIndex: mRect.pageIndex as Int, rect: intersection, readingClass: .high, classSource: mRect.classSource, pdfBase: pdfBase))
                }
            }
        }
        
        uniteRectangles(.high, onlySource: .localPeer)
        // - end intersection
        
        // Subtract critical (high) rects from interesting (medium) and read (low) rects
        subtractRectsOfClass(minuend: .medium, subtrahend: .high, onlySource: .localPeer)
        subtractRectsOfClass(minuend: .low, subtrahend: .high, onlySource: .localPeer)
        
        uniteRectangles(.medium, onlySource: .localPeer)
        // Subtract (remaining) interesting rects from read rects
        subtractRectsOfClass(minuend: .low, subtrahend: .medium, onlySource: .localPeer)
        
        uniteRectangles(.low, onlySource: .localPeer)
    }
    
    /// Unite all floating eye rectangles into bigger rectangles that enclose them
    mutating func flattenRectangles_eye() {
        uniteRectangles(.paragraph, onlySource: .smi)
    }
    
    /// Unite all rectangles of the given class
    /// Only the given class source is used (e.g. quick annotations and manual
    /// selection annotations are not combined)
    mutating func uniteRectangles(_ ofClass: ReadingClass, onlySource source: ClassSource) {
        // create set of all possible page indices
        var pis = Set<Int>()
        // only consider pages of interest to save time
        for rrect in allRects {
            if rrect.readingClass == ofClass && rrect.classSource == source {
                pis.insert(rrect.pageIndex)
            }
        }
        for page in pis {
            let rectsToUnite = allRects.filter({$0.readingClass == ofClass && $0.pageIndex == page && $0.classSource == source})
            allRects = allRects.filter({!($0.readingClass == ofClass && $0.pageIndex == page && $0.classSource == source)})
            let unitedRects = uniteCollidingRects(forPage: page, inputArray: rectsToUnite)
            allRects.append(contentsOf: unitedRects)
        }
    }
    
    /// Subtracts all rect of a given class from all rects of another class
    ///
    /// - parameter minuend: The class of rectangles to subtract from
    /// - parameter subtrahend: The class of rectangles that will be subtracted
    mutating func subtractRectsOfClass(minuend lhs: ReadingClass, subtrahend rhs: ReadingClass, onlySource source: ClassSource) {
        // create set of all possible page indices
        var pis = Set<Int>()
        // only consider pages of interest to save time
        for rrect in allRects.filter({$0.classSource == source}) {
            if rrect.readingClass == lhs || rrect.readingClass == rhs {
                pis.insert(rrect.pageIndex)
            }
        }
        for page in pis {
            // only continue if there is something to subtract in rhs
            let subtrahends = allRects.filter({$0.readingClass == rhs && $0.pageIndex == page && $0.classSource == source})
            if subtrahends.count > 0 {
                // assign minuends and remove them from allRects
                let minuends = allRects.filter({$0.readingClass == lhs && $0.pageIndex == page && $0.classSource == source})
                allRects = allRects.filter({!($0.readingClass == lhs && $0.pageIndex == page && $0.classSource == source)})
                let subtractedRects = subtractRectangles(forPage: page, minuends: minuends, subtrahends: subtrahends)
                // add result of subtraction back to allRects
                allRects.append(contentsOf: subtractedRects)
            }
        }
    }
    
    /// Calculate proportion of Read, Interesting and Critical markings for the given parameters.
    /// This is done by calculating the total area of each page and multiplying it by a constant.
    /// All rectangles (which will be united) are then cycled and the area of each is subtracted
    /// to calculate a proportion. Returns nil if no pdfBase is connected.
    /// If only new is set to true, calculates proportions only for rect which are marked as "new" (created during this reading session).
    mutating func calculateProportions_relevance(onlyNew: Bool = false) -> (proportionRead: Double, proportionInteresting: Double, proportionCritical: Double)? {
        flattenRectangles_relevance()
        var totalSurface = 0.0
        var readSurface = 0.0
        var interestingSurface = 0.0
        var criticalSurface = 0.0
        for pageI in 0 ..< pdfBase.document!.pageCount {
            let thePage = pdfBase.document!.page(at: pageI)
            let pageRect = pdfBase.getPageRect(thePage!)
            let pageSurface = Double(pageRect.size.height * pageRect.size.width)
            totalSurface += pageSurface
            for rect in get(ofClass: .low, forPage: pageI) {
                if !onlyNew || rect.new {
                    readSurface += Double(rect.rect.size.height * rect.rect.size.width)
                }
            }
            for rect in get(ofClass: .medium, forPage: pageI) {
                if !onlyNew || rect.new {
                    interestingSurface += Double(rect.rect.size.height * rect.rect.size.width)
                }
            }
            for rect in get(ofClass: .high, forPage: pageI) {
                if !onlyNew || rect.new {
                    criticalSurface += Double(rect.rect.size.height * rect.rect.size.width)
                }
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
        for pageI in 0..<pdfBase.document!.pageCount {
            let thePage = pdfBase.document!.page(at: pageI)
            let pageRect = pdfBase.getPageRect(thePage!)
            let pageSurface = Double(pageRect.size.height * pageRect.size.width)
            totalSurface += pageSurface
            for rect in get(onlyClass: .paragraph) {
                gazedSurface += Double(rect.rect.size.height * rect.rect.size.width)
            }
        }
        totalSurface *= PeyeConstants.pageAreaMultiplier
        let proportionGazed = gazedSurface / totalSurface
        return proportionGazed
    }
    
    /// Calculate the proportion of the document that has been displayed
    /// to the user (summated are of all viewports / total area of document)
    func calculateProportion_seen() -> Double? {
        
        guard let document = pdfBase.document, document.pageCount > 0 else {
            return nil
        }
        
        var totalSeenArea: Double = 0
        var totalPageArea: Double = 0
        
        for pNo in 0..<document.pageCount {
            
            var seenArea: Double = 0
            
            guard let page = document.page(at: pNo) else {
                AppSingleton.log.error("Failed to get page at \(pNo)")
                return nil
            }
            
            totalPageArea += Double(pdfBase.getPageRect(page).area)
            
            var computedRects = [NSRect]()
            
            for r in get(ofClass: .viewport, forPage: pNo) {
                var area = r.rect.area
                for cRect in computedRects.filter({$0.intersects(r.rect)}) {
                    area -= cRect.intersection(r.rect).area
                }
                seenArea += Double(area)
                computedRects.append(r.rect)
            }
            
            totalSeenArea += seenArea
        }
        
        let seenProportion = totalSeenArea / totalPageArea
        return seenProportion < 1 ? seenProportion : 1
    }
    
    /// Given an array of reading rectangles, return a sorted version of the array
    /// (sorted so that elements coming first should have been read first in western order)
    /// with the colliding rectangles united (two rects collide when their intersection is not zero).
    func uniteCollidingRects(forPage: Int, inputArray: [ReadingRect]) -> [ReadingRect] {
        var ary = inputArray
        ary.sort()
        var i = 0
        while i + 1 < ary.count {
            if ary[i].pageIndex != forPage {
                fatalError("Page indices for rects that have to be united do not match")
            }
            if NSIntersectsRect(ary[i].rect, ary[i+1].rect) {
                ary[i].unite(ary[i+1], pdfBase: pdfBase)
                ary.remove(at: i+1)
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
    func subtractRectangles(forPage: Int, minuends: [ReadingRect], subtrahends: [ReadingRect]) -> [ReadingRect] {
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
                        result.remove(at: i)
                        break
                    }
                }
                i += 1
            }
            
            collisions = !collidingRects.isEmpty
            
            for (minuendRect, subtrahendRect) in collidingRects {
                result.append(contentsOf: minuendRect.subtractRect(subtrahendRect, pdfBase: pdfBase))
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
    /// All rectangles representing a set of marks on a given document
    var rectState: [ReadingRect]
    /// The rectangles on which the last modification was made.
    /// If the change only affects one, this array contains one rect.
    /// If empty, assumes that this is change encompasses all document
    /// (this means that the whole pdfview, instead of a section, has to be refreshed)
    var lastRects: [ReadingRect] = []
    
    init(oldState: [ReadingRect]) {
        self.rectState = oldState
    }
}

// MARK: - Rectangle reading classes

/// How important is a paragraph
public enum ReadingClass: Int {
    case unset = 0
    case tag = 1  // note: this is treated separately ("tags" are not "marks")
    case viewport = 10
    case paragraph = 15
    case low = 20  // known as "read" in dime
    case foundString = 25
    case medium = 30  // known as "critical" in dime
    case high = 40  // known as "high" in dime
}

/// What decided that a paragraph is important
public enum ClassSource: Int {
    case unset = 0
    case viewport = 1
    case click = 2  // "Quick-annotate" function: double click for important, triple for critical
    case smi = 3
    case ml = 4
    case search = 5
    case localPeer = 6
    case networkPeer = 7
    case manualSelection = 8 // Selected by dragging and then setting importance
    case anyPeer = 9
}

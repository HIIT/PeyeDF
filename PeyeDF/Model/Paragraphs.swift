//
//  Paragraphs.swift
//  PeyeDF
//
//  Created by Marco Filetti on 02/11/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

// This source file contains classes helpful in identifying paragraphs (interesting / etc) in PDF documents

import Foundation

/// Represents all markings in a given PDF Document. Essentially, it uses PDF Page indices to index all rectangles (paragraphs) of a given importance
struct PDFMarkings {
    
    /// All rectangles (markings) for the given document.
    private var allRects = [ReadingRect]()
    
    /// Reference to mypdfbase is used to get text within reading rects and scaleFactors
    private weak var pdfBase: MyPDFBase?
    
    /// Create an empty state with markings of a given source using the given pdfBase to get text
    init(pdfBase: MyPDFBase?) {
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
    func get(forSource source: ClassSource, ofClass: ReadingClass) -> [ReadingRect] {
        return allRects.filter({$0.classSource == source && $0.readingClass == ofClass})
    }
    
    /// Returns all rectangles for a given class
    func get(ofClass theClass: ReadingClass) -> [ReadingRect] {
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
    
    /// Sets rects of a given class to the given dictionary. Traps if given reading class does not match this
    /// instance's class
    mutating func set(theClass: ReadingClass, _ rects: [ReadingRect]) {
        // remove all rects of the given class
        allRects = allRects.filter({$0.readingClass != theClass})
        for newRect in rects {
            if newRect.readingClass != theClass {
                fatalError("Added reading rect class does not match requested class")
            }
            if !allRects.contains(newRect) {
                allRects.append(newRect)
            }
        }
    }
    
    /// Set all rect with the given source to a new list of rects.
    /// Traps if not all rects passed have the given source.
    mutating func setAll(forSource source: ClassSource, newRects: [ReadingRect]) {
        allRects = allRects.filter({$0.classSource != source})
        for rect in newRects {
            if rect.classSource != source {
                fatalError("Passed rect with source \(rect.classSource) does not match \(source)")
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
    ///   For example, we show critical rectangles first, then interesting rectangles, then read ones.
    ///   This is because critical rectangles are assumed to be both interesting and read.
    mutating func flattenRectangles_relevance() {
        // "relevance" classes in order of importance: Critical, Interesting, Read
        uniteRectangles(.Critical)
        // Subtract critical rects from interesting and read rects
        subtractRectsOfClass(minuend: .Interesting, subtrahend: .Critical)
        subtractRectsOfClass(minuend: .Read, subtrahend: .Critical)
        
        uniteRectangles(.Interesting)
        // Subtract (remaining) interesting rects from read rects
        subtractRectsOfClass(minuend: .Read, subtrahend: .Interesting)
        
        uniteRectangles(.Read)
    }
    
    /// Unite all floating eye rectangles into bigger rectangles that enclose them and put them
    /// in their place in the allRects dictionary (under .Paragraph_united)
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
                ++i
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
        var collidingRects: [(lhsRect: ReadingRect, rhsRect: ReadingRect)] = [] // tuples with minuend rect and subtrahend rects which intersect (must be on the same page)
        
        // return the same result if there is nothing to subtract from / to
        if minuends.count == 0 || subtrahends.count == 0 {
            return minuends
        }
        
        var i = 0
        var result = minuends
        while i < result.count {
            let minuendRect = result[i]
            for subtrahendRect in subtrahends {
                if NSIntersectsRect(minuendRect.rect, subtrahendRect.rect) {
                    collidingRects.append((lhsRect: minuendRect, rhsRect: subtrahendRect))
                    result.removeAtIndex(i)
                    continue
                }
            }
            ++i
        }
        for (minuendRect, subtrahendRect) in collidingRects {
            result.appendContentsOf(minuendRect.subtractRect(subtrahendRect, pdfBase: pdfBase))
        }
        return result
    }
    
}
/// This class represents a "marking state", that is a selection of importance rectangles and the last rectangle and
/// last page that were edited. It is used to store states in undo operations.
class PDFMarkingsState: NSObject {
    /// All rectangles, prior to addition / deletion
    var rectState: [ReadingRect]
    /// The rectangle on which the last modification was made
    private var lastRect: ReadingRect?
    
    init(oldState: [ReadingRect]) {
        self.rectState = oldState
    }
    
    /// Sets the last rectangle (and on which page) that was added / removed
    func setLastRect(lastRect: ReadingRect) {
        self.lastRect = lastRect
    }
    
    /// Returns the last rectangle (if it exists). In the current implementation, this should never return nil.
    func getLastRect() -> ReadingRect? {
        return lastRect
    }
}

// MARK: - Rectangle reading classes

/// How important is a paragraph
public enum ReadingClass: Int {
    case Unset = 0
    case Viewport = 10
    case Paragraph = 15
    case Read = 20
    case FoundString = 25
    case Interesting = 30
    case Critical = 40
}

/// What decided that a paragraph is important
public enum ClassSource: Int {
    case Unset = 0
    case Viewport = 1
    case Click = 2
    case SMI = 3
    case ML = 4
    case Search = 5
}

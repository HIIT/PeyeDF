//
//  Paragraphs.swift
//  PeyeDF
//
//  Created by Marco Filetti on 02/11/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

// This source file contains classes helpful in identifying paragraphs (interesting / etc) in PDF documents

import Foundation

/// Represents all markings in a given PDF Document. Essentially, it uses PDFPages to index all rectangles (paragraphs) of a given importance
struct PDFMarkings {
    
    /// All rectangles (markings) for the given document.
    /// They are a dictionary of dictionaries, in which a reading classes indexes a dictionary.
    /// The second dictionary has a page indexing all rects on the given page (as an index from 0)
    private var allRects = [ReadingClass: [Int: [NSRect]]]()
    
    /// What is the source of this group of markings
    var source: ClassSource
    
    /// Create an empty state with markings of a given source
    init(withSource source: ClassSource) {
        self.source = source
        if source == .Click {
            // manually entered markings can only have these three classes (read is even for debug)
            for rc in [ReadingClass.Read, ReadingClass.Interesting, ReadingClass.Critical] {
                allRects[rc] = [Int: [NSRect]]()
            }
        } else if source == .SMI {
            // midas / smi eye tracking is only related to floating rectangles when initialized
            allRects[ReadingClass.Paragraph_floating] = [Int: [NSRect]]()
        } else {
            for rc in [ReadingClass.Paragraph_floating, ReadingClass.Paragraph_united, ReadingClass.Read, ReadingClass.Interesting, ReadingClass.Critical] {
                allRects[rc] = [Int: [NSRect]]()
            }
        }
    }
    
    /// Add a rect of the given class to the given page
    mutating func addRect(rect: NSRect, ofClass: ReadingClass, forPage: Int) {
        if allRects[ofClass]![forPage] == nil {
            allRects[ofClass]![forPage] = [NSRect]()
        }
        allRects[ofClass]![forPage]!.append(rect)
    }
    
    /// Returns all rectangles for a given class
    func get(theClass: ReadingClass) -> [Int: [NSRect]] {
        return allRects[theClass]!
    }
    
    /// Sets rects of a given class to the given dictionary
    mutating func set(theClass: ReadingClass, _ rects: [Int: [NSRect]]) {
        allRects[theClass] = rects
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
    
    /// Unite all rectangles of the given class
    mutating func uniteRectangles(ofClass: ReadingClass) {
        for page in allRects[ofClass]!.keys {
            allRects[ofClass]![page]! = uniteCollidingRects(allRects[ofClass]![page]!)
        }
    }
    
    /// Subtracts all rect of a given class from all rects of another class
    ///
    /// - parameter minuend: The class of rectangles to subtract from
    /// - parameter subtrahend: The class of rectangles that will be subtracted
    mutating func subtractRectsOfClass(minuend lhs: ReadingClass, subtrahend rhs: ReadingClass) {
        for page in allRects[lhs]!.keys {
            // only continue if there is something to subtract in rhs
            if let sRects = allRects[rhs]![page] {
                // set lhs to result of subtraction
                allRects[lhs]![page]! = subtractRectangles(allRects[lhs]![page]!, subtrahends: sRects)
            }
        }
    }
}

/// Given an array of rectangles, return a sorted version of the array
/// (sorted so that elements coming first should have been read first in western order)
/// with the colliding rectangles united (two rects collide when their intersection is not zero).
public func uniteCollidingRects(inputArray: [NSRect]) -> [NSRect] {
    var ary = inputArray
    ary.sortInPlace()
    var i = 0
    while i + 1 < ary.count {
        if NSIntersectsRect(ary[i], ary[i+1]) {
            ary[i] = NSUnionRect(ary[i], ary[i+1])
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
public func subtractRectangles(minuends: [NSRect], subtrahends: [NSRect]) -> [NSRect] {
    var collidingRects: [(lhsRect: NSRect, rhsRect: NSRect)] = [] // tuples with minuend rect and subtrahend rects which intersect (assumed to be on the same page)
    
    // return the same result if there is nothing to subtract from / to
    if minuends.count == 0 || minuends.count == 0 {
        return minuends
    }
    
    var i = 0
    var result = minuends
    while i < result.count {
        let minuendRect = result[i]
        for subtrahendRect in subtrahends {
            if NSIntersectsRect(minuendRect, subtrahendRect) {
                collidingRects.append((lhsRect: minuendRect, rhsRect: subtrahendRect))
                result.removeAtIndex(i)
                continue
            }
        }
        ++i
    }
    for (minuendRect, subtrahendRect) in collidingRects {
        result.appendContentsOf(minuendRect.subtractRect(subtrahendRect))
    }
    return result
}

/// This class represents a "marking state", that is a selection of importance rectangles and the last rectangle and
/// last page that were edited. It is used to store states in undo operations.
class PDFMarkingsState: NSObject {
    /// All rectangles, prior to addition / deletion
    var rectState: PDFMarkings
    /// The page on which the last modification was made
    private var lastPage: Int?
    /// The rectangle on which the last modification was made
    private var lastRect: NSRect?
    
    init(oldState: PDFMarkings) {
        self.rectState = oldState
    }
    
    /// Sets the last rectangle (and on which page) that was added / removed
    func setLastRect(lastRect: NSRect, lastPage: Int) {
        self.lastRect = lastRect
        self.lastPage = lastPage
    }
    
    /// Returns the last rectangle (if it exists). In the current implementation, this should never return nil.
    func getLastRect() -> (lastRect: NSRect, lastPage: Int)? {
        if let _ = self.lastPage {
            return (self.lastRect!, self.lastPage!)
        } else {
            return nil
        }
    }
}

// MARK: - Rectangle reading classes

/// How important is a paragraph
public enum ReadingClass: Int {
    case Unset = 0
    case Viewport = 10
    case Paragraph_floating = 13
    case Paragraph_united = 14
    case Read = 20
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
}

//
//  EyeRectangle.swift
//  PeyeDF
//
//  Created by Marco Filetti on 12/12/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Foundation

/// Represents a box sent to the eye tracking analysis algo
struct EyeRectangle: Dictionariable {
    
    /// Timestamp representing when this chunk of data was collected
    let unixt: Int
    
    /// Origin of this rect in page space
    let origin: NSPoint
    
    /// Size of this rect in page space
    let size: NSSize
    
    /// X coordinates in rectangle's space
    let Xs: [NSNumber]
    
    /// Y coordinates in rectangle's space
    let Ys: [NSNumber]
    
    /// Fixation durations
    let durations: [NSNumber]
    
    /// Index (from 0) of page in which this rect appeared
    let pageIndex: Int
    
    let readingClass: ReadingClass
    let classSource: ClassSource
    let scaleFactor: NSNumber
    let plainTextContent: NSString
    
    /// Given a page rect some a chunk of data (assumed to be on the same page, throws
    /// fatal error if not) returns an EyeRectangle corresponding to the "intersection"
    /// between the given rectangle and all data provided. Scale factors must also be equal.
    /// Fails (returns nil) if no data matched
    init?(fromPageRect readingRect: ReadingRect, andPageData pageData: PageEyeDataChunk) {
        if readingRect.pageIndex != pageData.pageIndex {
            fatalError("Given reading rect has page index: \(readingRect.pageIndex), while data has \(pageData.pageIndex)")
        }
        
        if readingRect.scaleFactor != pageData.scaleFactor {
            fatalError("Given reading rect has scale factor: \(readingRect.scaleFactor), while data has \(pageData.scaleFactor)")
        }
        
        var Xs = [NSNumber]()
        var Ys = [NSNumber]()
        var durations = [NSNumber]()
        
        for i in 0..<pageData.Xs.count {
            let fixPoint = NSPoint(x: pageData.Xs[i] as Double, y: pageData.Ys[i] as Double)
            if NSPointInRect(fixPoint, readingRect.rect) {
                let newPoint = fixPoint.pointInRectCoords(readingRect.rect)
                Xs.append(newPoint.x)
                Ys.append(newPoint.y)
                durations.append(pageData.durations[i])
            }
        }
        
        if Xs.count == 0 {
            return nil
        }
        
        self.Xs = Xs
        self.Ys = Ys
        self.pageIndex = pageData.pageIndex!
        self.durations = durations
        self.scaleFactor = pageData.scaleFactor
        self.readingClass = readingRect.readingClass
        self.classSource = readingRect.classSource
        self.plainTextContent = readingRect.plainTextContent ?? ""
        self.unixt = pageData.unixt
        self.origin = readingRect.rect.origin
        self.size = readingRect.rect.size
    }
    
    func getDict() -> [String: AnyObject] {
        var retVal = [String: AnyObject]()
        
        retVal["unixt"] = unixt
        retVal["origin"] = origin.getDict()
        retVal["size"] = size.getDict()
        retVal["Xs"] = Xs
        retVal["Ys"] = Ys
        retVal["durations"] = durations
        retVal["pageIndex"] = pageIndex
        retVal["readingClass"] = readingClass.rawValue
        retVal["classSource"] = classSource.rawValue
        retVal["scaleFactor"] = scaleFactor
        retVal["plainTextContent"] = plainTextContent
        
        return retVal
    }
    
    /// Given a readingevent and a PageEyeData (array of chunks), generate an EyeRectangle
    /// for each rectangle
    static func allEyeRectangles(fromReadingEvent readingEvent: ReadingEvent) -> [EyeRectangle] {
        
        var retVal = [EyeRectangle]()
        let eyeData = readingEvent.pageEyeData
        
        for rRect in readingEvent.pageRects {
            for dataChunk in eyeData {
                if rRect.pageIndex == dataChunk.pageIndex && rRect.scaleFactor == dataChunk.scaleFactor {
                    if let newEyeRect = EyeRectangle(fromPageRect: rRect, andPageData: dataChunk) {
                        retVal.append(newEyeRect)
                    }
                }
            }
        }
        
        return retVal
    }
}
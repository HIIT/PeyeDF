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
    
    /// Attention Value (if set)
    private(set) var attnVal: NSNumber?
    
    let readingClass: ReadingClass
    let classSource: ClassSource
    let scaleFactor: NSNumber
    let plainTextContent: String?
    
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
        
        if Xs.count < PeyeConstants.minNOfFixations {
            return nil
        }
        
        self.Xs = Xs
        self.Ys = Ys
        self.pageIndex = pageData.pageIndex!
        self.durations = durations
        self.scaleFactor = pageData.scaleFactor
        self.readingClass = readingRect.readingClass
        self.classSource = readingRect.classSource
        self.plainTextContent = readingRect.plainTextContent
        self.unixt = pageData.unixt
        self.origin = readingRect.rect.origin
        self.size = readingRect.rect.size
    }
    
    init(fromJson json: JSON) {
        self.unixt = json["unixt"].intValue
        self.origin = NSPoint(x: json["origin"]["x"].doubleValue, y: json["origin"]["y"].doubleValue)
        self.size = NSSize(width: json["size"]["width"].doubleValue, height: json["size"]["height"].doubleValue)
        
        self.Xs = json["Xs"].arrayObject! as! [NSNumber]
        self.Ys = json["Ys"].arrayObject! as! [NSNumber]
        self.durations = json["durations"].arrayObject! as! [NSNumber]
        
        self.pageIndex = json["pageIndex"].intValue
        if let attnVal = json["attnVal"].double {
            self.attnVal = attnVal
        }
        
        self.readingClass = ReadingClass(rawValue: json["readingClass"].intValue)!
        self.classSource = ClassSource(rawValue: json["classSource"].intValue)!
        
        self.scaleFactor = json["scaleFactor"].doubleValue
        self.plainTextContent = json["plainTextContent"].string
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
        if let ptc = plainTextContent {
            retVal["plainTextContent"] = ptc
        }
        if let attnVal = attnVal {
            retVal["attnVal"] = attnVal
        }
        
        return retVal
    }
    
    /// Given a readingevent and a PageEyeData (array of chunks), generate an EyeRectangle
    /// for each rectangle
    static func allEyeRectangles(fromReadingEvent readingEvent: ReadingEvent, forReadingClass readingClass: ReadingClass, andSource classSource: ClassSource) -> [EyeRectangle] {
        
        var retVal = [EyeRectangle]()
        let eyeData = readingEvent.pageEyeData
        
        // TODO: remove this
        var alreadyDoneRects = [ReadingRect]()
        
        for rRect in readingEvent.pageRects {
            if rRect.classSource == classSource && rRect.readingClass == readingClass {
                if !alreadyDoneRects.contains(rRect) {
                    alreadyDoneRects.append(rRect)
                    for dataChunk in eyeData {
                        if rRect.pageIndex == dataChunk.pageIndex && rRect.scaleFactor == dataChunk.scaleFactor {
                            if let newEyeRect = EyeRectangle(fromPageRect: rRect, andPageData: dataChunk) {
                                retVal.append(newEyeRect)
                            }
                        }
                    }
                }
            }
        }
        
        return retVal
    }
}
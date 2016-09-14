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

/// Represents a box sent to the eye tracking analysis algo
struct EyeRectangle: Dictionariable {
    
    /// Timestamp representing when this chunk of data was collected
    let unixt: Int
    
    /// Distance from screen when this eyerect was created
    fileprivate(set) var screenDistance: Double = 600.0
    
    /// Origin of this rect in page space
    fileprivate(set) var origin: NSPoint
    
    /// Size of this rect in page space
    fileprivate(set) var size: NSSize
    
    /// X coordinates in rectangle's space
    fileprivate(set) var Xs: [Double]
    
    /// Y coordinates in rectangle's space
    fileprivate(set) var Ys: [Double]
    
    /// Fixation durations
    fileprivate(set) var durations: [Int]
    
    /// Index (from 0) of page in which this rect appeared
    let pageIndex: Int
    
    /// Attention Value (if set)
    fileprivate(set) var attnVal: Double?
    
    /// Normalized attention value
    fileprivate(set) var attnVal_n: Double?
    
    let readingClass: ReadingClass
    let classSource: ClassSource
    let scaleFactor: Double
    fileprivate(set) var plainTextContent: String?
    
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
        
        var Xs = [Double]()
        var Ys = [Double]()
        var durations = [Int]()
        
        for i in 0..<pageData.Xs.count {
            let fixPoint = NSPoint(x: pageData.Xs[i] as Double, y: pageData.Ys[i] as Double)
            if NSPointInRect(fixPoint, readingRect.rect) {
                let newPoint = fixPoint.pointInRectCoords(readingRect.rect)
                Xs.append(Double(newPoint.x))
                Ys.append(Double(newPoint.y))
                durations.append(pageData.durations[i])
            }
        }
        
        if Xs.count < PeyeConstants.minNOfFixations {
            return nil
        }
        
        self.screenDistance = readingRect.screenDistance
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
        
        if let sd = json["screenDistance"].double {
            self.screenDistance = sd
        }
        self.Xs = json["Xs"].arrayObject! as! [Double]
        self.Ys = json["Ys"].arrayObject! as! [Double]
        self.durations = json["durations"].arrayObject! as! [Int]
        
        self.pageIndex = json["pageIndex"].intValue
        
        if let attnVal = json["attnVal"].double {
            self.attnVal = attnVal
        }
        if let attnVal_n = json["attnVal_n"].double {
            self.attnVal_n = attnVal_n
        }
        
        self.readingClass = ReadingClass(rawValue: json["readingClass"].intValue)!
        self.classSource = ClassSource(rawValue: json["classSource"].intValue)!
        
        self.scaleFactor = json["scaleFactor"].doubleValue
        self.plainTextContent = json["plainTextContent"].string
    }
    
    func getDict() -> [String: Any] {
        var retVal = [String: Any]()
        
        retVal["unixt"] = unixt
        retVal["origin"] = origin.getDict()
        retVal["size"] = size.getDict()
        retVal["Xs"] = Xs
        retVal["Ys"] = Ys
        retVal["screenDistance"] = screenDistance
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
        if let attnVal_n = attnVal_n {
            retVal["attnVal_n"] = attnVal_n
        }
        
        return retVal
    }
    
    /// Returns a new set of eye rectangles obtained by splitting and "cropping" the current
    /// one so that the height of each new rectangle corresponds to the given value
    /// - parameter maxHeight: the maximum height of the returned rectangles. Current rectangle will be divided into many rectangles of equal height (which will be less than this value)
    /// - parameter pdfBase: If set, will use given class to extract plainTextContent from PDF (plainTextContent will be nil otherwise)
    func splitAndCrop(_ dpi: Int, _ pdfBase: PDFBase?) -> [EyeRectangle] {
        // calculate max height by multiplying standard box size (3 visual angle calc) * 1.5
        let maxHeight = pointSpan(zoomLevel: CGFloat(self.scaleFactor), dpi: dpi, distancemm: CGFloat(self.screenDistance)) * 1.5
        
        // number of new rects
        let newNum = Int(ceil(self.size.height/maxHeight))
        if newNum == 1 {
            return [self]
        } else {
            // length of y for each rect
            let chunkl = self.size.height / CGFloat(newNum)
            
            // new rects are built bottom-to-top, so that towards the bottom
            // of the page we have rect 0

            var newRects = [EyeRectangle](repeating: self, count: newNum)
            for i in 0..<newNum {
                // set new origin and height
                newRects[i].origin.y += chunkl * CGFloat(i)
                newRects[i].size.height = chunkl
                // reset fixations
                newRects[i].Xs = []
                newRects[i].Ys = []
                newRects[i].durations = []
                // reset plain text
                newRects[i].plainTextContent = nil
            }
            
            // assign fixations to corresponding rect
            for i in 0..<self.Ys.count {
                let nr = Int(floor(CGFloat(Ys[i]) / chunkl))
                let newY = CGFloat(Ys[i]) - chunkl * CGFloat(nr)
                newRects[nr].Ys.append(Double(newY))
                newRects[nr].Xs.append(self.Xs[i])
                newRects[nr].durations.append(self.durations[i])
                if let pdfb = pdfBase {
                    newRects[nr].plainTextContent = pdfb.stringForRect(newRects[nr])
                }
            }
            
            // remove eyerects with too few fixations from return value
            return newRects.filter({$0.Xs.count > PeyeConstants.minNOfFixations})

        }
    }
    
    /// Given a readingevent and a PageEyeData (array of chunks), generate an EyeRectangle
    /// for each rectangle
    static func allEyeRectangles(fromReadingEvent readingEvent: ReadingEvent, forReadingClass readingClass: ReadingClass, andSource classSource: ClassSource, withPdfBase: PDFBase?) -> [EyeRectangle] {
        
        var retVal = [EyeRectangle]()
        let eyeData = readingEvent.pageEyeData
        
        for rRect in readingEvent.pageRects {
            if rRect.classSource == classSource && rRect.readingClass == readingClass {
                for dataChunk in eyeData {
                    if rRect.pageIndex == dataChunk.pageIndex && rRect.scaleFactor == dataChunk.scaleFactor {
                        if let newEyeRect = EyeRectangle(fromPageRect: rRect, andPageData: dataChunk) {
                            
                            // split and crop obtained rectangle before adding it to return value
                            // use 90 as default DPI (SMI's monitor DPI)
                            let splitRects = newEyeRect.splitAndCrop(readingEvent.dpi ?? 90, withPdfBase)
                            retVal.append(contentsOf: splitRects)
                        }
                    }
                }
            }
        }
        
        return retVal
    }
    
}

extension Sequence where Iterator.Element == EyeRectangle {
    
    /// Create (or modify) attVal_n of all eye rectangles so that they range between 0 and 1
    func normalize() -> [EyeRectangle] {
        let attnVals: [Double] = self.map({$0.attnVal! as Double})
        let minVal = attnVals.min()!
        let maxVal = attnVals.max()!
        return self.map() {
            var retVal = $0
            retVal.attnVal_n = ($0.attnVal! as Double - minVal) / (maxVal - minVal)
            return retVal
        }
    }
    
}

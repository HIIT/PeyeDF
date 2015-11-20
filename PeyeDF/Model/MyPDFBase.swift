//
//  MyPDFBase.swift
//  PeyeDF
//
//  Created by Marco Filetti on 04/11/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Cocoa
import Foundation
import Quartz

/// Base class extended by all PDF renderers (MyPDFReader, MyPDFOverview, MyPDFDetail) used in PeyeDF
/// support custom "markings" and their writing to annotation
class MyPDFBase: PDFView {
    
    let extraLineAmount = 2 // 1/this number is the amount of extra lines that we want to discard
    // if we are at beginning or end of paragraph

    /// Stores all manually entered markings
    var manualMarks: PDFMarkings!
    
    /// Stores all markings from smi (to check all rects the user fixated upon)
    var smiMarks: PDFMarkings!
    
    /// Stores all markings from searches
    var searchMarks: PDFMarkings!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        manualMarks = PDFMarkings(withSource: ClassSource.Click, pdfBase: self)
        smiMarks = PDFMarkings(withSource: ClassSource.SMI, pdfBase: self)
        searchMarks = PDFMarkings(withSource: ClassSource.Search, pdfBase: self)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        manualMarks = PDFMarkings(withSource: ClassSource.Click, pdfBase: self)
        smiMarks = PDFMarkings(withSource: ClassSource.SMI, pdfBase: self)
        searchMarks = PDFMarkings(withSource: ClassSource.Search, pdfBase: self)
    }
    
    // MARK: - External functions
    
    /// Get media box for page, representing coordinates which take into account if
    /// page has been cropped (in Preview, for example). By default returns
    /// media box instead if crop box is not present, which is what we want
    func getPageRect(page: PDFPage) -> NSRect {
        return page.boundsForBox(kPDFDisplayBoxCropBox)
    }
    
    /// Get the number of visible page numbers (starting from 0)
    func getVisiblePageNums() -> [Int] {
        var visibleArray = [Int]()
        for visiblePage in self.visiblePages() as! [PDFPage] {
            visibleArray.append(document().indexForPage(visiblePage))
        }
        return visibleArray
    }
    
    /// Get the number of visible page labels (as embedded in the PDF)
    func getVisiblePageLabels() -> [String] {
        var visibleArray = [String]()
        for visiblePage in self.visiblePages() as! [PDFPage] {
            visibleArray.append(visiblePage.label())
        }
        return visibleArray
    }
    
    /// Returns the list of rects corresponding to portion of pages being seen
    func getVisibleRects() -> [NSRect] {
        let visiblePages = self.visiblePages()
        var visibleRects = [NSRect]()  // rects in page coordinates, one for each page, representing visible portion
        
        for visiblePage in visiblePages as! [PDFPage] {
            
            // Get page's rectangle coordinates
            let pageRect = getPageRect(visiblePage)
            
            // Get viewport rect and apply margin
            var visibleRect = NSRect(origin: CGPoint(x: 0, y: 0), size: self.frame.size)
            visibleRect.insetInPlace(dx: PeyeConstants.extraMargin, dy: PeyeConstants.extraMargin)
            
            visibleRect = self.convertRect(visibleRect, toPage: visiblePage)  // Convert rect to page coordinates
            
            visibleRect.intersectInPlace(pageRect)  // Intersect to get seen portion
            
            // make sure rect size is >0, <page size and origin > 0 < page size 
            if visibleRect.origin.x >= 0 && visibleRect.origin.y >= 0 &&
               visibleRect.origin.x < pageRect.size.width &&
               visibleRect.origin.y < pageRect.size.height &&
               visibleRect.size.width > 0 && visibleRect.size.height > 0 &&
               visibleRect.size.width <= pageRect.size.width &&
               visibleRect.size.height <= pageRect.size.height {
                visibleRects.append(visibleRect)
            }
            
        }
        return visibleRects
    }
    
    /// Returns a string corresponding to the text contained within the given rect at the given page index
    ///
    /// - parameter rect: The rect for which we want the string for
    /// - parameter onPage: Index starting from 0 on which the rect is
    /// - returns: A string if it was possible to generate it, nil if not
    func stringForRect(rect: NSRect, onPage: Int) -> String? {
        if self.document().getText() != nil {
            let page = document().pageAtIndex(onPage)
            let selection = page.selectionForRect(rect)
            return selection.string()
        } else {
            return nil
        }
    }
    
    /// Convenience function to get a string from a readingrect
    func stringForReadingRect(theRect: ReadingRect) -> String? {
        return stringForRect(theRect.rect, onPage: theRect.pageIndex.integerValue)
    }
    
    /// Manually set all rectangles to the given parameters, and annotate them.
    func setMarksAndAnnotate(newManualMarks: PDFMarkings) {
        manualMarks = newManualMarks
        autoAnnotate()
    }
    
    /// Returns a rectangle corresponding to the annotation for a rectangle corresponding to the mark, using all appropriate constants / preferences.
    ///
    /// - parameter markRect: The rectangle corresponding to the mark
    /// - returns: A rectangle representing the annotation
    func annotationRectForMark(markRect: NSRect) -> NSRect {
        let lineThickness = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefAnnotationLineThickness) as! CGFloat
        let newRect_x = markRect.origin.x - PeyeConstants.annotationLineDistance
        let newRect_y = markRect.origin.y
        let newRect_height = markRect.height
        let newRect_width: CGFloat = lineThickness
        return NSRect(x: newRect_x, y: newRect_y, width: newRect_width, height: newRect_height)
    }
    
    
    /// Create PDFAnnotationSquare related to the markings of the specified class
    ///
    /// - parameter forClass: The class of annotations to output
    /// - parameter colour: The color to use, generally defined in PeyeConstants
    func outputAnnotations(forClass: ReadingClass, colour: NSColor) {
        let lineThickness: CGFloat = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefAnnotationLineThickness) as! CGFloat
        let myBord = PDFBorder()
        myBord.setLineWidth(lineThickness)
        
        for rect in manualMarks.get(forClass) {
            let newRect = annotationRectForMark(rect.rect)
            let annotation = PDFAnnotationSquare(bounds: newRect)
            annotation.setColor(colour)
            annotation.setBorder(myBord)
            
            let pdfPage = self.document().pageAtIndex(rect.pageIndex.integerValue)
            
            pdfPage.addAnnotation(annotation)
            
            // tell the view to immediately refresh itself in an area which includes the
            // line's "border"
            setNeedsDisplayInRect(convertRect(newRect, fromPage: pdfPage))
        }
    }
    
    /// Remove all annotations which are a "square" and match the annotations colours
    /// defined in PeyeConstants
    func removeAllAnnotations() {
        for i in 0..<document()!.pageCount() {
            let page = document()!.pageAtIndex(i)
            for annColour in PeyeConstants.annotationAllColours {
                for annotation in page.annotations() {
                    if let annotation = annotation as? PDFAnnotationSquare {
                        if annotation.color().practicallyEqual(annColour) {
                            page.removeAnnotation(annotation)
                        }
                    }
                }
            }
        }
    }
    
    
    /// Writes all annotations corresponding to all marks, and deletes intersecting rectangles for "lower-class" rectangles which
    /// intersect with "higher-class" rectangles
    func autoAnnotate() {
        removeAllAnnotations()
        manualMarks.flattenRectangles_relevance()
        outputAnnotations(.Critical, colour: PeyeConstants.annotationColourCritical)
        outputAnnotations(.Interesting, colour: PeyeConstants.annotationColourInteresting)
        outputAnnotations(.Read, colour: PeyeConstants.annotationColourRead)
    }
    
    
    /// Calculate proportion of Read, Interesting and Critical markings.
    /// This is done by calculating the total area of each page and multiplying it by a constant.
    /// All rectangles (which will be united) are then cycled and the area of each is subtracted
    /// to calculate a proportion.
    func calculateProportions_manual() -> (proportionRead: Double, proportionInteresting: Double, proportionCritical: Double) {
        manualMarks.flattenRectangles_relevance()
        var totalSurface = 0.0
        var readSurface = 0.0
        var interestingSurface = 0.0
        var criticalSurface = 0.0
        for pageI in 0..<document().pageCount() {
            let thePage = document().pageAtIndex(pageI)
            let pageRect = getPageRect(thePage)
            let pageSurface = Double(pageRect.size.height * pageRect.size.width)
            totalSurface += pageSurface
            for rect in manualMarks.get(.Read, forPage: pageI) {
                readSurface += Double(rect.rect.size.height * rect.rect.size.width)
            }
            for rect in manualMarks.get(.Interesting, forPage: pageI) {
                interestingSurface += Double(rect.rect.size.height * rect.rect.size.width)
            }
            for rect in manualMarks.get(.Critical, forPage: pageI) {
                criticalSurface += Double(rect.rect.size.height * rect.rect.size.width)
            }
        }
        totalSurface *= PeyeConstants.pageAreaMultiplier
        let proportionRead = readSurface / totalSurface
        let proportionInteresting = interestingSurface / totalSurface
        let proportionCritical = criticalSurface / totalSurface
        return (proportionRead: proportionRead, proportionInteresting: proportionInteresting, proportionCritical: proportionCritical)
    }
    
    /// Calculate proportion of gazed-at united rectangles.
    /// This is done by calculating the total area of each page and multiplying it by a constant.
    /// All rectangles (which will be united) are then cycled and the area of each is subtracted
    /// to calculate a proportion.
    func calculateProportion_smi() -> Double {
        smiMarks.flattenRectangles_eye()
        var totalSurface = 0.0
        var gazedSurface = 0.0
        for pageI in 0..<document().pageCount() {
            let thePage = document().pageAtIndex(pageI)
            let pageRect = getPageRect(thePage)
            let pageSurface = Double(pageRect.size.height * pageRect.size.width)
            totalSurface += pageSurface
            for rect in smiMarks.get(.Paragraph) {
                gazedSurface += Double(rect.rect.size.height * rect.rect.size.width)
            }
        }
        totalSurface *= PeyeConstants.pageAreaMultiplier
        let proportionGazed = gazedSurface / totalSurface
        return proportionGazed
    }
    
    // MARK: - Internal functions
    
    /// Converts a point to a rectangle corresponding to the paragraph in which the point resides.
    ///
    /// - parameter pagePoint: the point of interest
    /// - parameter forPage: the page of interest
    /// - returns: A rectangle corresponding to the point, nil if there is no paragraph
    internal func pointToParagraphRect(pagePoint: NSPoint, forPage activePage: PDFPage) -> NSRect? {
        
        let pageRect = getPageRect(activePage)
        let maxH = pageRect.size.width - 5.0  // maximum horizontal size for line
        let maxV = pageRect.size.height / 3.0  // maximum vertical size for line
        
        let minH: CGFloat = 2.0
        let minV: CGFloat = 5.0
        
        let pointArray = verticalFocalPoints(fromPoint: pagePoint, zoomLevel: self.scaleFactor(), pageRect: self.getPageRect(activePage))
        
        // if using columns, selection can "bleed" into footers and headers
        // solution: check the median height and median width of each selection, and discard
        // everything which is lineAutoSelectionTolerance bigger than that
        var selections = [PDFSelection]()
        for point in pointArray {
            let sel = activePage.selectionForLineAtPoint(point)
            let selRect = sel.boundsForPage(activePage)
            let seenRect = getSeenRect(fromPoint: pagePoint, zoomLevel: self.scaleFactor())
            // only add selection if its rect intersect estimated seen rect
            // and if selection rect is less than maximum h and v size but more than minimum
            if selRect.intersects(seenRect) && selRect.size.width < maxH &&
               selRect.size.height < maxV && selRect.size.width > minH &&
               selRect.size.height > minV {
                    
                // only add selection if it wasn't added before
                var foundsel = false
                for oldsel in selections {
                    if sel.equalsTo(oldsel) {
                        foundsel = true
                        break
                    }
                }
                if foundsel {
                    continue
                }
                selections.append(sel)
            }
        }
        
        if selections.count == 0 {
            return nil
        }
        
        let medI = selections.count / 2  // median point for selection array
        
        // sort selections by height (disabled, using middle point instead)
        // selections.sort({$0.boundsForPage(activePage).height > $1.boundsForPage(activePage).height})
        let medianHeight = selections[medI].boundsForPage(activePage).height
        
        // sort selections by width (disabled, using median point)
        // selections.sort({$0.boundsForPage(activePage).width > $1.boundsForPage(activePage).width})
        let medianWidth = selections[medI].boundsForPage(activePage).width
        
        let isHorizontalLine = medianHeight < medianWidth
        
        // If the line is vertical, skip
        if !isHorizontalLine {
            return nil
        }
        
        let medianSize = NSSize(width: medianWidth, height: medianHeight)
        
        // reject selections which are too big
        let filteredSelections = selections.filter({$0.boundsForPage(activePage).size.withinMaxTolerance(medianSize, tolerance: PeyeConstants.lineAutoSelectionTolerance)})
        
        var pdfSel = PDFSelection(document: self.document())
        for selection in filteredSelections {
            pdfSel.addSelection(selection)
        }
        
        // if top / bottom third of the lines comprise a part of another paragraph, leave them out
        // detect this by using new lines
        
        // get selection line by line
        if let selLines = pdfSel.selectionsByLine() {
            let nOfExtraLines: Int = Int(floor(CGFloat(selLines.count) / CGFloat(extraLineAmount)))
            
            // split selection into beginning / end separating by new line
            
            // only proceed if there are extra lines
            if nOfExtraLines > 0 {
                var lineStartIndex = 0
                // check if part before new line is included in any of the extra beginning lines,
                // if so skip them
                for i in 0..<nOfExtraLines {
                    let currentLineSel = selLines[i] as! PDFSelection
                    let cLString = currentLineSel.string() + "\r"
                    if let _ = activePage.string().rangeOfString(cLString) {
                        lineStartIndex = i+1
                        break
                    }
                }
                
                // do the same for the ending part
                var lineEndIndex = selLines.count-1
                for i in Array((selLines.count-1-nOfExtraLines..<selLines.count).reverse()) {
                    let currentLineSel = selLines[i] as! PDFSelection
                    let cLString = currentLineSel.string() + "\r"
                    if let _ = activePage.string().rangeOfString(cLString) {
                        lineEndIndex = i
                        break
                    }
                }
                
                if lineEndIndex < lineStartIndex {
                    return nil
                }
                
                // generate new selection not taking into account excluded parts
                pdfSel = PDFSelection(document: self.document())
                for i in lineStartIndex...lineEndIndex {
                    pdfSel.addSelection(selLines[i] as! PDFSelection)
                }
                
            } // end of check for split, if no need just return selection as-was //
        } else {
            return nil
        }
        
        // The new rectangle for this point
        return pdfSel.boundsForPage(activePage)
    }
    
}

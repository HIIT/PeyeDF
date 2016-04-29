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

import Cocoa
import Foundation
import Quartz

/// Base class extended by all PDF renderers (MyPDFReader, MyPDFOverview, MyPDFDetail) used in PeyeDF
/// support custom "markings" and their writing to annotation
class MyPDFBase: PDFView {
    
    let extraLineAmount = 2 // 1/this number is the amount of extra lines that we want to discard
    // if we are at beginning or end of paragraph

    /// Stores all markings
    var markings: PDFMarkings!
    
    /// Whether this document contains plain text
    private(set) var containsPlainText = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        markings = PDFMarkings(pdfBase: self)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        markings = PDFMarkings(pdfBase: self)
    }
    
    // MARK: - Tagging (external)
    
    /// All tags currently stored (changing this causes refresh of display and adjusts related annotations)
    var readingTags = [ReadingTag]() { willSet {
        let added = newValue.filter({!readingTags.contains($0)})  // added items
        let removed = readingTags.filter({!newValue.contains($0)})  // removed items
        added.forEach({makeTagAnnotation(forTag: $0)})
        removed.forEach({removeTagAnnotation(forTag: $0)})
    } }
    
    /// Returns a list of tags associated to a given selection
    func tagsForSelection(sel: PDFSelection) -> [ReadingTag] {
        let (rects, idxs) = getLineRects(sel)
        return readingTags.filter({$0.containsNSRects(rects, onPages: idxs)})
    }
    
    /// Show tag popup for readingtags at this point.
    /// Returns true if some tags where indeed present (false if the point is a "miss").
    func showTags(forPoint: NSPoint) -> Bool {
        
        
        // Page we're on.
        let activePage = self.pageForPoint(forPoint, nearest: true)
        
        // Index for current page
        let pageIndex = self.document().indexForPage(activePage)
        
        // Point in page space
        let pagePoint = convertPoint(forPoint, toPage: activePage)
        
        // Find tuples for which this point falls in an annotation
        let tuples = tagAnnotations.filter({$0.annotations.contains({$0.page() === activePage && NSPointInRect(pagePoint, $0.bounds())})})
        
        if tuples.count > 0 {
            
            let sel = activePage.selectionForRect(tuples[0].annotations[0].bounds())
            dispatch_async(dispatch_get_main_queue()) {
                self.setCurrentSelection(sel)
            }
            
            return true
        } else {
            return false
        }
    }
    
    // MARK: - Tagging (private)
    
    /// Tuples that relate sets of pdf annotations to their related tags
    /// (since a block of text can have multiple tags)
    private var tagAnnotations = [(annotations: [PDFAnnotationMarkup], tags: [ReadingTag])]()
    
    /// Keeps track of index of the last tuple of tags that was selected
    /// (so that when multiple tagged blocks of text overlap, multiple clicks cycle through them)
    private var lastTagAnnotationIndex: Int = 0
    
    /// Creates annotation(s) for the given tag (and stores this relationship for later use)
    private func makeTagAnnotation(forTag tag: ReadingTag) {
        
        // Make sure tag was not already added
        guard tagAnnotations.reduce(false, combine: {$0 || $1.tags.contains(tag) }) == false else {
            return
        }
        
        // find which group of annotations corresponds to this tag.
        // if none are related, create a new group of annotations.
        // if there is a relationship, add this tag to the tuple without creating new annotations.
        
        var foundI = -1
        for (i, t) in tagAnnotations.enumerate() {
            let tagRects = tag.rects.map{$0.rect}
            let pages = tag.rects.map{$0.pageIndex as Int}
            if t.tags[0].containsNSRects(tagRects, onPages: pages) {  // assume the first tag refers to the same regions as the others in the tuple
                foundI = i
                break
            }
        }
        
        if foundI == -1 {
            
            // no tags already exist which relate to this block of text
            
            var annots = [PDFAnnotationMarkup]()
            for rRect in tag.rects {
                let annotation = PDFAnnotationMarkup(bounds: rRect.rect)
                annotation.setColor(PeyeConstants.annotationColourTagged)
                
                let pdfPage = self.document().pageAtIndex(rRect.pageIndex as Int)
                
                pdfPage.addAnnotation(annotation)
                annots.append(annotation)
                
                // refresh view
                dispatch_async(dispatch_get_main_queue()) {
                    self.setNeedsDisplayInRect(self.convertRect(rRect.rect, fromPage: pdfPage))
                }
            }
            
            // create new entry in tuple
            tagAnnotations.append((annotations: annots, tags: [tag]))
            
        } else {
            // add tag to tuple
            tagAnnotations[foundI].tags.append(tag)
        }
        
    }
    
    /// Removes annotation(s) for the given tag (removing both)
    private func removeTagAnnotation(forTag tag: ReadingTag) {
        
        // make sure tag exists and get index in its tuple
        
        var tupleI = -1
        var tagI = -1
        
        for (i, t) in tagAnnotations.enumerate() {
            if let j = t.tags.indexOf(tag) {  // assume the first tag refers to the same regions as the others in the tuple
                tupleI = i
                tagI = j
                break
            }
        }
        
        guard tupleI != -1 else {
            AppSingleton.log.error("Tag not found in already existing tags")
            return
        }
        
        // remove tag from tuple. if no tags are left in that tuple, delete entry and annotations
        
        tagAnnotations[tupleI].tags.removeAtIndex(tagI)
        
        if tagAnnotations[tupleI].tags.count == 0 {
            
            for annot in tagAnnotations[tupleI].annotations {
            
                let pdfPage = annot.page()
                
                pdfPage.removeAnnotation(annot)
                
                // refresh view
                dispatch_async(dispatch_get_main_queue()) {
                    self.setNeedsDisplayInRect(self.convertRect(annot.bounds(), fromPage: pdfPage))
                }
            }
            
            tagAnnotations.removeAtIndex(tupleI)
        }
        
    }
    
    // MARK: - External functions
    
    /// Returns all rects and page indices covered by this selection, line by line
    func getLineRects(sel: PDFSelection) -> ([NSRect], [Int]) {
        var rects = [NSRect]()
        var idxs = [Int]()
        for subSel in (sel.selectionsByLine() as! [PDFSelection]) {
            for p in subSel.pages() as! [PDFPage] {
                let pageIndex = self.document().indexForPage(p)
                let rect = subSel.boundsForPage(p)
                rects.append(rect)
                idxs.append(pageIndex)
            }
        }
        return (rects, idxs)
    }
    
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

    /// Returns all text from contained document (nil if not present)
    /// - Warning: Time-consuming for long documents, blocks thread.
    func getDocText() -> String? {
        if let doc = self.document() {
            return doc.getText()
        } else {
            return nil
        }
    }

    /// Asynchronously gets text within document (if any) and
    /// calls callback with the result.
    func checkPlainText(callback: (String? -> Void)?) {
        if let doc = self.document() {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
                [weak self] in
                if let txt = doc.getText() {
                    self?.containsPlainText = true
                    callback?(txt)
                } else {
                    callback?(nil)
                }
            }
        } else {
            callback?(nil)
        }
    }
    
    /// Returns a string corresponding to the text contained within the given rect at the given page index
    ///
    /// - parameter rect: The rect for which we want the string for
    /// - parameter onPage: Index starting from 0 on which the rect is
    /// - returns: A string if it was possible to generate it, nil if not
    func stringForRect(rect: NSRect, onPage: Int) -> String? {
        if containsPlainText {
            let page = document().pageAtIndex(onPage)
            let selection = page.selectionForRect(rect)
            return selection.string()
        } else {
            return nil
        }
    }
    
    /// Convenience function to get a string from a readingrect
    func stringForRect(theRect: ReadingRect) -> String? {
        return stringForRect(theRect.rect, onPage: theRect.pageIndex.integerValue)
    }
    
    /// Convenience function to get a string from a eyerect
    func stringForRect(theRect: EyeRectangle) -> String? {
        return stringForRect(NSRect(origin: theRect.origin, size: theRect.size), onPage: theRect.pageIndex)
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
        
        for rect in markings.get(onlyClass: forClass) {
            let newRect = annotationRectForMark(rect.rect)
            let annotation = PDFAnnotationSquare(bounds: newRect)
            annotation.setColor(colour)
            annotation.setBorder(myBord)
            
            let pdfPage = self.document().pageAtIndex(rect.pageIndex.integerValue)
            
            pdfPage.addAnnotation(annotation)
            
            // tell the view to immediately refresh itself in an area which includes the
            // line's "border"
            dispatch_async(dispatch_get_main_queue()) {
                self.setNeedsDisplayInRect(self.convertRect(newRect, fromPage: pdfPage))
            }
        }
    }
    
    /// Remove all annotations which are a "square" and match the annotations colours
    /// (corresponding to interesting/ etc. marks) defined in PeyeConstants
    func removeAllParagraphAnnotations() {
        for i in 0..<document()!.pageCount() {
            let page = document()!.pageAtIndex(i)
            for annColour in PeyeConstants.markAnnotationColours.values {
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
        removeAllParagraphAnnotations()
        markings.flattenRectangles_relevance()
        outputAnnotations(.Critical, colour: PeyeConstants.annotationColourCritical)
        outputAnnotations(.Interesting, colour: PeyeConstants.annotationColourInteresting)
        outputAnnotations(.Read, colour: PeyeConstants.annotationColourRead)
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

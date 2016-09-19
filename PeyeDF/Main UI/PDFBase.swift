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

/// Base class extended by all PDF renderers (PDFReader, PDFOverview, MyPDFDetail) used in PeyeDF
/// support custom "markings" and their writing to annotation
class PDFBase: PDFView {
    
    /// Whether we are searching (set this to false to stop search)
    var searching = false
    
    /// Whether the mouse is currently being dragged
    fileprivate(set) var mouseDragging = false
    
    /// The TagAnnotation currently being dragged
    fileprivate(set) var draggedTagAnnotation: Int?
    
    /// The index of last tuple selected is set to this value when nothing is selected
    fileprivate static let TAGI_NONE: Int = 99999
    
    /// Ignore TAG selection colour
    fileprivate static let TAGI_SKIP: Int = 99998
    
    let extraLineAmount = 2 // 1/this number is the amount of extra lines that we want to discard
    // if we are at beginning or end of paragraph

    /// Stores all markings
    var markings: PDFMarkings!
    
    /// Which colours are associated to which reading class (can be overridden in subclasses)
    var markAnnotationColours: [ReadingClass: NSColor] { get {
        return [.low: PeyeConstants.annotationColourRead,
                .medium: PeyeConstants.annotationColourInteresting,
                .high: PeyeConstants.annotationColourCritical]
    } }
    
    /// This rect (in page coordinates) on this page index will be "highlighted"
    var highlightRect: (pageIndex: Int, rect: NSRect)? = nil { didSet {
        // Changing this value will cause a display refresh (if old if different than current value).
        if let (newPageI, newRect) = highlightRect {
            // refresh new and old if different, or just new if old was nil
            if let (oldPageI, oldRect) = oldValue {
                if oldPageI != newPageI || oldRect != newRect {
                    refreshPage(atIndex: oldPageI, rect: oldRect)
                    refreshPage(atIndex: newPageI, rect: newRect)
                }
            } else {
                refreshPage(atIndex: newPageI, rect: newRect)
            }
        } else {
            // new value is nil, refresh old if present
            if let (oldPageI, oldRect) = oldValue {
                refreshPage(atIndex: oldPageI, rect: oldRect)
            }
        }
    } }
   
    /// All tags currently stored.
    /// This is in the same structure as DiMe's tags (one tag can reference multiple parts of the text).
    /// Changing this value updates the internal representation (`splitTag`), which stores tags in a
    /// different way (one tag per nearby block of text, tags with the same name can be duplicated).
    var readingTags = [ReadingTag]() {
        willSet {
            let oldTagStrings = Set(readingTags.map({$0.text}))
            let newTagStrings = Set(newValue.map({$0.text}))
            let changedTagStrings = oldTagStrings.intersection(newTagStrings)
            
            // put old and new changed tags in a tuple (if different)
            let changedTags: [(ReadingTag, ReadingTag)] = changedTagStrings.flatMap({
                string in
                let oldTag = readingTags.filter({$0.text == string})
                let newTag = newValue.filter({$0.text == string})
                if oldTag.count != 1 || newTag.count != 1 {
                    AppSingleton.log.error("Changed tag filter returned more than one tag")
                }
                if newTag[0].rRects.nearlyEqual(oldTag[0].rRects) {
                    return nil
                } else {
                    return (oldTag[0], newTag[0])
                }
            })
            
            // get difference for each tag, and apply add or remove accordingly
            changedTags.forEach({
                (oldTag, newTag) in
                let (added, removed) = oldTag.rectDifference(newTag)
                if added.count > 0 {
                    let newTag = ReadingTag(withRects: added, withText: oldTag.text)
                    appendTagAnnotation(forTag: newTag)
                }
                if removed.count > 0 {
                    let delTag = ReadingTag(withRects: removed, withText: oldTag.text)
                    removeTagAnnotation(forTag: delTag)
                }
            })
            
            // calculate completely (not changed) new tags
            let added = newValue.filter({!changedTagStrings.contains($0.text) && !readingTags.contains($0)})
            // calculate completely (not changed) removed tags
            let removed = readingTags.filter({!changedTagStrings.contains($0.text) && !newValue.contains($0)})
            
            // split completely new tags, and for each collection of split tags, make an annotation for each
            added.forEach({appendTagAnnotation(forTag: $0)})
            
            // just remove completely removed tags
            removed.forEach({removeTagAnnotation(forTag: $0)})
        }
    }
    
    /// Whether this document contains plain text
    fileprivate(set) var containsPlainText = false
    
    /// Here we store tags and annotations that refer to a single block of
    /// text (block being defined as text in contiguous lines in the PDF).
    /// Each entry can have multiple annotations and multiple tags. In this structure,
    /// multiple lines can have the same tag repeated (unlike in DiMe, were there can only be
    /// one tag with a given name). For example, we can have two instances of tag with name "useful",
    /// one on page two and another on page three.
    fileprivate var tagAnnotations = [TagAnnotation]()
    
    /// Keeps track of index of the last tuple of tags that was selected
    /// Setting this value automatically sets tag colour and refreshes view
    /// TAGI_NONE means nothng is selected
    fileprivate var lastTagAnnotationIndex: Int = PDFBase.TAGI_NONE { didSet {
        
        // if skiped, assume we selected none next time and abort
        guard lastTagAnnotationIndex != PDFBase.TAGI_SKIP else {
            lastTagAnnotationIndex = PDFBase.TAGI_NONE
            return
        }
        
        // set colours
        DispatchQueue.main.async {
            // new selection colour
            if self.lastTagAnnotationIndex != PDFBase.TAGI_NONE {
                self.tagAnnotations[self.lastTagAnnotationIndex].setSelected()
            }
            
            // previously selected back to normal
            if oldValue != PDFBase.TAGI_NONE {
                self.tagAnnotations[oldValue].setUnselected()
            }
        }
        
    } }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        markings = PDFMarkings(pdfBase: self)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        markings = PDFMarkings(pdfBase: self)
    }
    
    // MARK: - Drawing
    
    /**
    Causes a display refresh on the given page index.
    - Parameter rect: The rect to refresh (in page coordinates). If nil (default), refreshes the whole page (crop box).
    */
    func refreshPage(atIndex index: Int, rect: NSRect? = nil) {
        guard let doc = document, let page = doc.getPage(atIndex: index) else {
            return
        }
        var refRect: NSRect
        if rect == nil {
            refRect = page.bounds(for: PDFDisplayBox.cropBox)
        } else {
            refRect = rect!
        }
        refRect = self.convert(refRect, from: page)
        DispatchQueue.main.async {
            self.setNeedsDisplay(refRect)
        }
    }
    
    /**
    Gets a point representing the offset (from 0,0) between media box and crop box.
    Normally, we use the media box to store rect coordinates. In case there is a difference with the
     crop box (for display reasons), this function returns that difference.
    */
    func offSetToCropBox(_ page: PDFPage!) -> NSPoint {
        // if origins of media and boxes are different, obtain difference
        // to later apply it to each readingrect's origin
        let mediaBoxo = page.bounds(for: PDFDisplayBox.mediaBox).origin
        let cropBoxo = page.bounds(for: PDFDisplayBox.cropBox).origin
        var pointDiff = NSPoint(x: 0, y: 0)
        if mediaBoxo != cropBoxo {
            pointDiff.x = mediaBoxo.x - cropBoxo.x
            pointDiff.y = mediaBoxo.y - cropBoxo.y
        }
        return pointDiff
    }

    override func draw(_ page: PDFPage) {
        super.draw(page)
        
        // get difference between media and crop box
        let pointDiff = offSetToCropBox(page)
        
        // if the highlight rect is present on the current page, draw it
        if let (pageIndex, rect) = highlightRect , document!.index(for: page) == pageIndex {
            
            // Save.
            NSGraphicsContext.saveGraphicsState()
            
            let rectCol = PeyeConstants.highlightRectColour
            let adjRect = rect.offset(byPoint: pointDiff)
            let rectPath: NSBezierPath = NSBezierPath(rect: adjRect)
            rectCol.setFill()
            rectPath.fill()
            
            // Restore.
            NSGraphicsContext.restoreGraphicsState()
        }
    }
    
    // MARK: - Input overrides
    
    /// Mouse down captures (does not send to super) when there is a tag label underneath
    override func mouseDown(with theEvent: NSEvent) {
        let mouseInWindow = theEvent.locationInWindow
        let mouseInView = self.convert(mouseInWindow, from: self.window!.contentViewController!.view)
        guard let activePage = self.page(for: mouseInView, nearest: false) else {
            super.mouseDown(with: theEvent)
            return
        }
        let pointOnPage = self.convert(mouseInView, to: activePage)
        if let i = tagAnnotations.index(where: {$0.labelHitTest(pointOnPage, page: activePage)}) {
            draggedTagAnnotation = i
        } else {
            super.mouseDown(with: theEvent)
            draggedTagAnnotation = nil
        }
    }
    
    /// Dragging is overriden to allow us to drag labels
    override func mouseDragged(with theEvent: NSEvent) {
        self.mouseDragging = true
        // if we are dragging a tag label, override so we move label, otherwise not
        let mouseInWindow = theEvent.locationInWindow
        let mouseInView = self.convert(mouseInWindow, from: self.window!.contentViewController!.view)
        guard let activePage = self.page(for: mouseInView, nearest: false), let draggedTagI = self.draggedTagAnnotation else {
            super.mouseDragged(with: theEvent)
            self.draggedTagAnnotation = nil
            return
        }
        let mouseOnPage = self.convert(mouseInView, to: activePage)
        tagAnnotations[draggedTagI].moveLabel(mouseOnPage)
    }
    
    /// Mouse up is overridden to allow "dropping" the dragged tag label
    override func mouseUp(with theEvent: NSEvent) {
        self.mouseDragging = false
        self.draggedTagAnnotation = nil
        super.mouseUp(with: theEvent)
    }
    
    // MARK: - Tagging (internal)
    
    /// If there is a block of text currently being clicked on,
    /// returns the tags associated to it.
    func currentlyClickedOnTags() -> [ReadingTag]? {
        if lastTagAnnotationIndex != PDFBase.TAGI_NONE {
            return tagAnnotations[lastTagAnnotationIndex].tags
        } else {
            return nil
        }
    }
    
    /// Acknowledges the fact that the user is not interested in a specific tag anymore.
    func clearClickedOnTags() {
        lastTagAnnotationIndex = PDFBase.TAGI_NONE
    }
    
    /// Returns a list of tags associated to a given selection
    func tagsForSelection(_ sel: PDFSelection) -> [ReadingTag] {
        let (rects, idxs) = getLineRects(sel)
        return readingTags.filter({$0.containsNSRects(rects, onPages: idxs)})
    }
    
    /// Show tag popup for readingtags at this point.
    /// Returns true if some tags where indeed present (false if the point is a "miss").
    func showTags(_ forPoint: NSPoint) -> Bool {
        
        // Page we're on.
        let activePage = self.page(for: forPoint, nearest: true)
        
        // Point in page space
        let pagePoint = convert(forPoint, to: activePage!)
        
        // Find tuples for which this point falls in an annotation
        let tupleI = tagAnnotations.index(where: {$0.hitTest(pagePoint, page: activePage!)})
        
        if let i = tupleI {
            
            lastTagAnnotationIndex = i  // automatically refreshes view
            
            (self.window!.windowController as! DocumentWindowController).tagShow(self)
            
            return true
        } else {
            // no tuples found
            clearClickedOnTags()
            return false
        }
    }
    
    /// Performs an asynchronous tag (readingtag) search on the utility queue.
    /// For every instance of a tag found, sends a tagStringFoundNotification back on the main queue.
    func beginTagStringSearch(_ tagString: String) {
        
        self.searching = true
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
            // loop on tag annotations, since those are split by "closeness" (unlike the readingTags array, which contains whole tags)
            self.tagAnnotations.forEach() {
                
                // check if we are searching (if not, skip rest)
                guard self.searching else {
                    return
                }
                
                if let foundSel = $0.getPdfSelection(tagString) {
                    // create and send notification
                    var uInfo = [String: AnyObject]()
                    uInfo["MyPDFTagFoundSelection"] = foundSel
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Notification.Name(rawValue: TagConstants.tagStringFoundNotification), object: self, userInfo: uInfo)
                    }
                }
            }
            
            self.searching = false
        }
    }
    
    /// Creates annotation(s) for the given tag or add it to already present annotations.
    /// Splits them as necessary.
    fileprivate func appendTagAnnotation(forTag tag: ReadingTag) {
        
        // Make sure tag was not already added
        guard tagAnnotations.reduce(false, {$0 || $1.tags.contains(tag) }) == false else {
            AppSingleton.log.error("A tag exactly the same as this was already present")
            return
        }
        
        // find which group of annotations corresponds to this tag.
        // if none are related, create a new group of annotations.
        // if there is a relationship, add this tag without creating new annotations.
        
        let previous = tagAnnotations.filter({$0.sameAnnotationsAs(tag)})
        if previous.count == 0 {
            // since no tags already exist which relate to this block of text, split them
            // split Tags, map each returned collection to a new reading tag
            let splitTags = tag.rRects.splitOnBigSteps(self.document!.areFar).map({ReadingTag(withRects: $0, withText: tag.text)})
            // if split count is more than 1, call this method recursively, otherwise create a new tag annotation for the new tag
            if splitTags.count > 1 {
                splitTags.forEach({appendTagAnnotation(forTag: $0)})
            } else if splitTags.count == 1 {
                tagAnnotations.append(TagAnnotation(fromReadingTag: splitTags[0], pdfBase: self))
            } else {
                AppSingleton.log.error("Zero tags where obtained by splitting a tag that contained something")
            }
        } else {
            if previous.count != 1 {
                AppSingleton.log.error("More than one tag annotation was already related to an existing tag")
            }
            previous[0].addTag(tag)
        }
        
    }
    
    /// Removes annotation(s) for the given tag (removing both)
    fileprivate func removeTagAnnotation(forTag tag: ReadingTag) {
        
        // make sure tag exists and get index
        // remove tag and if remaining 0 remove from collection
        
        let _found = tagAnnotations.index(where: {$0.sameAnnotationsAs(tag)})
        
        guard let foundI = _found else {
            AppSingleton.log.error("Tag not found in already existing tags")
            return
        }
        
        // before annotation removal, set selection to none
        
        self.lastTagAnnotationIndex = type(of: self).TAGI_SKIP
        
        if tagAnnotations[foundI].removeTag(tag) < 1 {
            tagAnnotations[foundI].removeAll()
            tagAnnotations.remove(at: foundI)
        }
    }
    
    // MARK: - External functions
    
    /// Returns all rects and page indices covered by this selection, line by line
    func getLineRects(_ sel: PDFSelection) -> ([NSRect], [Int]) {
        var rects = [NSRect]()
        var idxs = [Int]()
        for subSel in (sel.selectionsByLine() ) {
            for p in subSel.pages {
                let pageIndex = self.document!.index(for: p)
                let rect = subSel.bounds(for: p)
                rects.append(rect)
                idxs.append(pageIndex)
            }
        }
        return (rects, idxs)
    }
    
    /// Get media box for page, representing coordinates which take into account if
    /// page has been cropped (in Preview, for example). By default returns
    /// media box instead if crop box is not present, which is what we want
    func getPageRect(_ page: PDFPage) -> NSRect {
        return page.bounds(for: PDFDisplayBox.cropBox)
    }
    
    /// Get the number of visible page numbers (starting from 0)
    func getVisiblePageNums() -> [Int] {
        var visibleArray = [Int]()
        for visiblePage in self.visiblePages()! where self.visiblePages() != nil {
            visibleArray.append(document!.index(for: visiblePage))
        }
        return visibleArray
    }
    
    /// Get the number of visible page labels (as embedded in the PDF)
    func getVisiblePageLabels() -> [String] {
        var visibleArray = [String]()
        for visiblePage in self.visiblePages()!.flatMap({$0}) {
            visibleArray.append(visiblePage.label!)
        }
        return visibleArray
    }
    
    /// Returns the list of rects corresponding to portion of pages being seen
    func getVisibleRects() -> [NSRect] {
        
        var visibleRects = [NSRect]()  // rects in page coordinates, one for each page, representing visible portion
        
        for visiblePage in self.visiblePages()! where self.visiblePages() != nil {
            
            // Get page's rectangle coordinates
            let pageRect = getPageRect(visiblePage)
            
            // Get viewport rect and apply margin
            var visibleRect = NSRect(origin: CGPoint(x: 0, y: 0), size: self.frame.size)
            visibleRect = visibleRect.insetBy(dx: PeyeConstants.extraMargin, dy: PeyeConstants.extraMargin)
            
            visibleRect = self.convert(visibleRect, to: visiblePage)  // Convert rect to page coordinates
            
            visibleRect = visibleRect.intersection(pageRect)  // Intersect to get seen portion
            
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
        if let doc = self.document {
            return doc.getText()
        } else {
            return nil
        }
    }
    
    /// Asynchronously gets text within document (if any) and
    /// calls callback with the result.
    func checkPlainText(_ callback: ((String?) -> Void)?) {
        if let doc = self.document {
            DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
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
    func stringForRect(_ rect: NSRect, onPage: Int) -> String? {
        if containsPlainText {
            let page = document!.page(at: onPage)
            let selection = page!.selection(for: rect)
            return selection!.string
        } else {
            return nil
        }
    }
    
    /// Convenience function to get a string from a readingrect
    func stringForRect(_ theRect: ReadingRect) -> String? {
        return stringForRect(theRect.rect, onPage: theRect.pageIndex)
    }
    
    /// Convenience function to get a string from a eyerect
    func stringForRect(_ theRect: EyeRectangle) -> String? {
        return stringForRect(NSRect(origin: theRect.origin, size: theRect.size), onPage: theRect.pageIndex)
    }
        
    /// Create PDFAnnotationSquare related to the markings of the specified class
    ///
    /// - parameter forClass: The class of annotations to output
    /// - parameter colour: The color to use, generally defined in PeyeConstants
    func outputAnnotations(_ forClass: ReadingClass, colour: NSColor) {
        let lineThickness: CGFloat = UserDefaults.standard.value(forKey: PeyeConstants.prefAnnotationLineThickness) as! CGFloat
        let myBord = PDFBorder()
        myBord.lineWidth = lineThickness
        
        for rect in markings.get(onlyClass: forClass) {
            let newRect = rect.annotationRect
            let annotation = PDFAnnotationSquare(bounds: newRect)
            annotation.color = colour
            annotation.border = myBord
            
            let pdfPage = self.document!.page(at: rect.pageIndex)
            
            addAnnotation(annotation, onPage: pdfPage!)
            
        }
    }
    
    /// Remove all annotations which are a "square" and match the annotations colours
    /// (corresponding to low/medium/high marks) defined in PeyeConstants
    func removeAllParagraphAnnotations() {
        for i in 0..<document!.pageCount {
            let page = document!.page(at: i)
            for annColour in markAnnotationColours.values {
                for annotation in page!.annotations {
                    if let annotation = annotation as? PDFAnnotationSquare {
                        if annotation.color.practicallyEqual(annColour) {
                            removeAnnotation(annotation, onPage: page!)
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
        outputAnnotations(.high, colour: PeyeConstants.annotationColourCritical)
        outputAnnotations(.medium, colour: PeyeConstants.annotationColourInteresting)
        outputAnnotations(.low, colour: PeyeConstants.annotationColourRead)
    }
    
    // MARK: - Convenience functions
    
    /// Adds the given annotation on the given page and refreshes display
    internal func addAnnotation(_ annotation: PDFAnnotation, onPage: PDFPage) {
        onPage.addAnnotation(annotation)
        DispatchQueue.main.async {
            self.setNeedsDisplay(self.convert(annotation.bounds, from: onPage))
            self.layoutDocumentView()
        }
    }
    
    /// Removes the given annotation from the given page and refreshes display
    internal func removeAnnotation(_ annotation: PDFAnnotation, onPage: PDFPage) {
        onPage.removeAnnotation(annotation)
        DispatchQueue.main.async {
            self.setNeedsDisplay(self.convert(annotation.bounds, from: onPage))
        }
    }
    
    /// Moves the given annotation so that is centred on a given point (in page coordinates).
    internal func moveAnnotation(_ annotation: PDFAnnotation, toPoint: NSPoint) {
        let oldBounds = annotation.bounds
        let newOrigin = NSPoint(x: toPoint.x - annotation.bounds.size.width / 2, y: toPoint.y - annotation.bounds.size.height / 2)
        let newBounds = NSRect(origin: newOrigin, size: oldBounds.size)
        annotation.bounds = newBounds
        DispatchQueue.main.async {
            self.setNeedsDisplay(self.convert(oldBounds, from: annotation.page!))
            self.setNeedsDisplay(self.convert(newBounds, from: annotation.page!))
        }
    }
    
    /// Converts a point to a rectangle corresponding to the paragraph in which the point resides.
    ///
    /// - parameter pagePoint: the point of interest
    /// - parameter forPage: the page of interest
    /// - returns: A rectangle corresponding to the point, nil if there is no paragraph
    internal func pointToParagraphRect(_ pagePoint: NSPoint, forPage activePage: PDFPage) -> NSRect? {
        
        let pageRect = getPageRect(activePage)
        let maxH = pageRect.size.width - 5.0  // maximum horizontal size for line
        let maxV = pageRect.size.height / 3.0  // maximum vertical size for line
        
        let minH: CGFloat = 2.0
        let minV: CGFloat = 5.0
        
        let pointArray = verticalFocalPoints(fromPoint: pagePoint, zoomLevel: self.scaleFactor, pageRect: self.getPageRect(activePage))
        
        // if using columns, selection can "bleed" into footers and headers
        // solution: check the median height and median width of each selection, and discard
        // everything which is lineAutoSelectionTolerance bigger than that
        var selections = [PDFSelection]()
        for point in pointArray {
            let sel = activePage.selectionForLine(at: point)
            let selRect = sel!.bounds(for: activePage)
            let seenRect = getSeenRect(fromPoint: pagePoint, zoomLevel: self.scaleFactor)
            // only add selection if its rect intersect estimated seen rect
            // and if selection rect is less than maximum h and v size but more than minimum
            if selRect.intersects(seenRect) && selRect.size.width < maxH &&
               selRect.size.height < maxV && selRect.size.width > minH &&
               selRect.size.height > minV {
                    
                // only add selection if it wasn't added before
                var foundsel = false
                for oldsel in selections {
                    if sel!.equalsTo(oldsel) {
                        foundsel = true
                        break
                    }
                }
                if foundsel {
                    continue
                }
                selections.append(sel!)
            }
        }
        
        if selections.count == 0 {
            return nil
        }
        
        let medI = selections.count / 2  // median point for selection array
        
        // sort selections by height (disabled, using middle point instead)
        // selections.sort({$0.boundsForPage(activePage).height > $1.boundsForPage(activePage).height})
        let medianHeight = selections[medI].bounds(for: activePage).height
        
        // sort selections by width (disabled, using median point)
        // selections.sort({$0.boundsForPage(activePage).width > $1.boundsForPage(activePage).width})
        let medianWidth = selections[medI].bounds(for: activePage).width
        
        let isHorizontalLine = medianHeight < medianWidth
        
        // If the line is vertical, skip
        if !isHorizontalLine {
            return nil
        }
        
        let medianSize = NSSize(width: medianWidth, height: medianHeight)
        
        // reject selections which are too big
        let filteredSelections = selections.filter({$0.bounds(for: activePage).size.withinMaxTolerance(medianSize, tolerance: PeyeConstants.lineAutoSelectionTolerance)})
        
        var pdfSel = PDFSelection(document: self.document!)
        for selection in filteredSelections {
            pdfSel.add(selection)
        }
        
        // if top / bottom third of the lines comprise a part of another paragraph, leave them out
        // detect this by using new lines
        
        // get selection line by line
        let selLines = pdfSel.selectionsByLine()
        if selLines.count > 0 {
            let nOfExtraLines: Int = Int(floor(CGFloat(selLines.count) / CGFloat(extraLineAmount)))
            
            // split selection into beginning / end separating by new line
            
            // only proceed if there are extra lines
            if nOfExtraLines > 0 {
                var lineStartIndex = 0
                // check if part before new line is included in any of the extra beginning lines,
                // if so skip them
                for i in 0..<nOfExtraLines {
                    let currentLineSel = selLines[i]
                    if let cLString = currentLineSel.string, let _ = activePage.string?.range(of: cLString + "\r") {
                        lineStartIndex = i+1
                        break
                    }
                }
                
                // do the same for the ending part
                var lineEndIndex = selLines.count-1
                for i in Array((selLines.count-1-nOfExtraLines..<selLines.count).reversed()) {
                    let currentLineSel = selLines[i]
                    if let cLString = currentLineSel.string, let _ = activePage.string?.range(of: cLString + "\r") {
                        lineEndIndex = i
                        break
                    }
                }
                
                if lineEndIndex < lineStartIndex {
                    return nil
                }
                
                // generate new selection not taking into account excluded parts
                pdfSel = PDFSelection(document: self.document!)
                for i in lineStartIndex...lineEndIndex {
                    pdfSel.add(selLines[i])
                }
                
            } // end of check for split, if no need just return selection as-was //
        } else {
            return nil
        }
        
        // The new rectangle for this point
        return pdfSel.bounds(for: activePage)
    }
    
    /// Re-loads the view on the main queue.
    func refreshAll() {
        DispatchQueue.main.async {
            self.layoutDocumentView()
            self.display()
        }
    }
    
}

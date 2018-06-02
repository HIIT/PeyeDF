//
// Copyright (c) 2018 University of Helsinki, Aalto University
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
import Quartz
import os.log

/**
This class wraps all PDFAnnotation classes related to Tag(s) associated to
a "nearby" block of text (nearby is defined in the `splitReadingTag` function, which is used to define "contiguous" lines of text).
 Each Tag annotation contains multiple `PDFAnnotationMarkup` (for multiple lines of text) and
 a pair of (`PDFAnnotationFreeText`, `PDFAnnotationSquare`) which are used to draw
 a little block containing the tag's text. It can also contain multiple ReadingTags (since many tags can refer to the same block of text).
*/
class TagAnnotation: Equatable {

    /// Convenience field for the page index on which this TagAnnotation resides
    let pageIndex: Int
    
    /// Convenience field to access the PDFView (PDFBase) that created these annotations
    unowned let pdfBase: PDFBase
    
    /// All lines of text related to all our tags are marked up using this.
    fileprivate(set) var markups: [PDFAnnotationMarkup]
    
    /// All tags associated to this block of text.
    /// There should be only one entry with a given title (tag.text should be unique here).
    fileprivate(set) var tags = [ReadingTag]()
    
    /// The label showing the tag on the PDF. More than one if more tags are associated to it. Same order as tags.
    fileprivate(set) var labels = [PDFAnnotationFreeText]()
    
    /// The label's background. More than one if more tags are associated to it. Same order as labels.
    fileprivate(set) var labelBacks = [PDFAnnotationSquare]()
    
    // The label / label back pair index that was last hit (used when dragging labels).
    fileprivate var lastLabelHit: Int?
    
    /// Creates a block of annotations from a reading tag
    init?(fromReadingTag tag: ReadingTag, pdfBase: PDFBase) {
        
        self.pageIndex = tag.rRects[0].pageIndex as Int
        
        guard let document = pdfBase.document, let pdfPage = document.page(at: self.pageIndex as Int) else {
            return nil
        }
        
        var annots = [PDFAnnotationMarkup]()
        for rRect in tag.rRects {
            let annotation = PDFAnnotationMarkup(bounds: rRect.rect)
            
            annotation.color = TagConstants.annotationColourTagged
            
            DispatchQueue.main.async {
                pdfPage.addAnnotation(annotation)
            }
            annots.append(annotation)
            
        }
        
        self.pdfBase = pdfBase
        self.tags.append(tag)
        self.markups = annots
        let (label, labelBack) = TagAnnotation.makeLabelPair(tag, pdfPage: pdfPage, pdfBase: pdfBase)
        labels.append(label)
        labelBacks.append(labelBack)
        
        // Report error if page index is different in any reading tag
        tag.rRects.forEach() {
            if $0.pageIndex as Int != self.pageIndex {
                if #available(OSX 10.12, *) {
                    os_log("Tag annotation page index %d is different from a page index of a contained reading tag %d", type: .error, self.pageIndex, $0.pageIndex)
                }
            }
        }
    }
    
    /// Adds a tag to this block of text, adding also a label for the given tag
    func addTag(_ tag: ReadingTag) {
        tags.append(tag)
        addTagLabel(tag)
    }
    
    /// Removes a tag from this block of text. Returns count of remaining tags after removal. Also removes associated label.
    func removeTag(_ tag: ReadingTag) -> Int {
        guard let i = self.tags.index(of: tag) else {
            if #available(OSX 10.12, *) {
                os_log("Could not find requested tag", type: .error)
            }
            return tags.count
        }
        tags.remove(at: i)
        let lab = labels.remove(at: i)
        pdfBase.removeAnnotation(lab, onPage: lab.page!)
        let labBack = labelBacks.remove(at: i)
        pdfBase.removeAnnotation(labBack, onPage: lab.page!)
        return tags.count
    }
    
    /// Returns true when this tag annotations refers to the same blocks of text as
    /// the given reading tag (used to add reading tags to already present annotations).
    func sameAnnotationsAs(_ tag: ReadingTag) -> Bool {
        let tagRects = tag.rRects.map{$0.rect}
        let pages = tag.rRects.map{$0.pageIndex as Int}
        if tags[0].containsNSRects(tagRects, onPages: pages) {  // assume the first tag refers to the same regions as the others
            return true
        }
        return false
    }
    
    /// Returns true if the given point on the given page overlaps with any markup or tag label
    func hitTest(_ point: NSPoint, page: PDFPage) -> Bool {
        return labelHitTest(point, page: page) || markups.index() {
            markup in
            return NSPointInRect(point, markup.bounds)
        } != nil
    }
    
    /// Returns true if the given point is within a label's bounds.
    /// Also sets internal dragged label index.
    func labelHitTest(_ point: NSPoint, page:PDFPage) -> Bool {
        guard pdfBase.document!.index(for: page) == self.pageIndex else {
            return false
        }
        lastLabelHit = labelBacks.index(where: {NSPointInRect(point, $0.bounds)})
        return lastLabelHit != nil
    }
    
    /// Moves the last label and background hit to a given point (in page coordinates).
    func moveLabel(_ to: NSPoint) {
        guard let i = lastLabelHit else {
            return
        }
        pdfBase.moveAnnotation(labelBacks[i], toPoint: to)
        pdfBase.moveAnnotation(labels[i], toPoint: to)
    }
    
    /// Set the markups to the selected colour and refreshes view
    func setSelected() {
        markups.forEach() {
            $0.color = TagConstants.annotationColourTaggedSelected
            let annRect = pdfBase.convert($0.bounds, from: $0.page!)
            DispatchQueue.main.async {
                self.pdfBase.setNeedsDisplay(annRect)
            }
        }
    }
    
    /// Set the markups to the unselected colour and refreshes view
    func setUnselected() {
        markups.forEach() {
            $0.color = TagConstants.annotationColourTagged
            let annRect = pdfBase.convert($0.bounds, from: $0.page!)
            DispatchQueue.main.async {
                self.pdfBase.setNeedsDisplay(annRect)
            }
        }
    }
    
    
    /// Returns a selection covering the markups within for the given tag text (if present).
    func getPdfSelection(_ forTag: String) -> PDFSelection? {
        var foundSel: PDFSelection?
        // filter should return only one match
        let wantedTags = tags.filter({$0.text == forTag})
        if wantedTags.count > 1 {
            if #available(OSX 10.12, *) {
                os_log("More than one tag in tuple with the same text", type: .error)
            }
        }
        
        // If any tags were found, selection will be updated
        wantedTags.forEach() {
            wantedTag in

            if wantedTag.rRects.count < 1 {
                if #available(OSX 10.12, *) {
                    os_log("Tag has less than one rect", type: .error)
                }
                return
            }
            // selection for first rect
            guard let doc = pdfBase.document, let page = doc.getPage(atIndex: wantedTag.rRects[0].pageIndex as Int), let pdfSel = page.selection(for: wantedTag.rRects[0].rect.outset(1.0)) else {
                if #available(OSX 10.12, *) {
                    os_log("Selection is nil", type: .error)
                }
                return
            }
            
            // subsequent rects
            wantedTag.rRects[1..<wantedTag.rRects.count].forEach({pdfSel.add(doc.page(at: $0.pageIndex as Int)!.selection(for: $0.rect.outset(1.0))!)})

            foundSel = pdfSel
        }
        return foundSel
    }

    /// Removes all annotations from all pages and causes a display refresh.
    func removeAll() {
        markups.forEach() {
            pdfBase.removeAnnotation($0, onPage: $0.page!)
        }
        labels.forEach() {
            pdfBase.removeAnnotation($0, onPage: $0.page!)
        }
        labelBacks.forEach() {
            pdfBase.removeAnnotation($0, onPage: $0.page!)
        }
    }
    
    // MARK: Convenience (drawing)
    
    /// Creates a tag label and a background for a given readingtag
    fileprivate static func makeLabelPair(_ tag: ReadingTag, pdfPage: PDFPage, pdfBase: PDFBase) -> (PDFAnnotationFreeText, PDFAnnotationSquare) {
        
        let offset: CGFloat = 10  // distance between paragraph and label
        
        let font = TagConstants.tagLabelFont!
        let size = sizeForText(tag.text, font: font)
        
        // origin of label is horigontally, left or right of largest rect
        // vertically, middle of union of all rects
        
        let rectSpan = tag.rRects.reduce(NSRect()) {NSUnionRect($0, $1.rect)}
        
        var origin = NSPoint(x: -1, y: rectSpan.origin.y + rectSpan.size.height / 2)
        
        // put tag annotation on left or right of related text depending on whether
        // the related text is on the left or right side of the page
        
        if (rectSpan.minX + rectSpan.size.width / 2) > pdfPage.bounds(for: PDFDisplayBox.cropBox).width / 2 {
            origin.x = rectSpan.maxX + offset
        } else {
            origin.x = rectSpan.minX - offset - size.width
        }
        
        let annBounds = NSRect(origin: origin, size: size)
        let textAnnotation = PDFAnnotationFreeText(bounds: annBounds)
        textAnnotation.bounds.origin.y -= textAnnotation.bounds.height / 4  // center text vertically in box
        textAnnotation.color = NSColor.clear
        textAnnotation.setAlignment(.center)
        textAnnotation.setFontColor(NSColor.black)
        textAnnotation.setFont(font)
        textAnnotation.contents = tag.text
        let box = PDFAnnotationSquare(bounds: annBounds.addTo(1))
        box.setInteriorColor(TagConstants.annotationColourTagLabelBackground)
        box.color = NSColor.clear
        
        pdfBase.addAnnotation(box, onPage: pdfPage)
        pdfBase.addAnnotation(textAnnotation, onPage: pdfPage)
        
        return (textAnnotation, box)
    }
    
    /// Moves current tag labels and annotations up to add a new label, and adds it to the current annotations.
    func addTagLabel(_ forTag: ReadingTag) {
        
        /// Inner function to get a point which corresponds to half the size of the given annotation + padding, moved up (adding to y)
        func moveUp(_ annot: PDFAnnotation, padding: CGFloat) -> NSPoint {
            var point = annot.bounds.origin
            point.y += annot.bounds.height
            point.x += annot.bounds.width / 2
            point.y += padding
            return point
        }
        
        let padding = TagConstants.tagLabelPadding
        
        // create pair
        let pdfPage = pdfBase.document!.page(at: forTag.rRects[0].pageIndex as Int)
        let (newText, newBack) = TagAnnotation.makeLabelPair(forTag, pdfPage: pdfPage!, pdfBase: pdfBase)
        
        let ourRect = newBack.bounds
        let count: CGFloat = CGFloat(labels.count)
        
        // move all tags found in destination area up to make space for this one
        // 1) destination area is this label back boundary+padding * number of already existing tags (origin shifted half down to centre)
        let destVertSpan: CGFloat = (ourRect.size.height + padding) * count
        var destRect = ourRect
        destRect.origin.y -= destVertSpan / 2
        destRect.size.height = destVertSpan
        
        // 2) get current pairs (which overlap to this tag final area) and move them up
        let oLabels = labels.filter({NSIntersectsRect($0.bounds, destRect)})
        let oBacks = labelBacks.filter({NSIntersectsRect($0.bounds, destRect)})
        
        // 3) move found pairs up (each by half its size + padding)
        oLabels.forEach() {
            let point = moveUp($0, padding: padding)
            pdfBase.moveAnnotation($0, toPoint: point)
        }
        oBacks.forEach() {
            let point = moveUp($0, padding: padding)
            pdfBase.moveAnnotation($0, toPoint: point)
        }
        
        // 4) move current pair to bottom (point - found pairs in step four * (size_of_each + padding)/2 )
        // size_of_each is average of their summation
        let size = oBacks.map{$0.bounds.height}.reduce(0, +) / CGFloat(oBacks.count)
        var finalPoint = NSPoint(x: ourRect.midX, y: ourRect.midY)
        finalPoint.y -= count * (size + padding) / 2
        
        // add created annotation to collection
        pdfBase.moveAnnotation(newText, toPoint: finalPoint)
        pdfBase.moveAnnotation(newBack, toPoint: finalPoint)
        labels.append(newText)
        labelBacks.append(newBack)
    }
}

/// Two tag annotations are equal when the reading tags in them are the same
func == (rhs: TagAnnotation, lhs: TagAnnotation) -> Bool {
    return rhs.tags.elementsEqual(lhs.tags)
}

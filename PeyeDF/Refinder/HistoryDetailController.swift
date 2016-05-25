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
import Quartz

/// This protocol is implemeted by classes that want to display in detail an history element (which is a tuple of ReadingEvent and 
/// ScientificDocument). Used to inform the pdf history display classes on which history item was selected and to
/// communicate which rects to display.
protocol HistoryDetailDelegate: class {
    /// Returns a pdf base which can handle rect-to-text, for example
    func getPdfBase() -> MyPDFBase?
    
    /// Tells the delegate that a new item was selected. Resets setEyeRects
    func historyElementSelected(tuple: (ev: ReadingEvent, ie: ScientificDocument))
    
    /// Tells the delegate that a new set of eye rectangles should be shown next time
    func setEyeRects(eyeRects: [EyeRectangle])
    
    /// Tells the delegate to focus on an area (does it after a delay)
    func focusOn(area: FocusArea)
    
    /// Tells the delegate to display the current (communicated via setEyeRects) set of eye rectangles by converting them to
    /// a set of markings (reading rect) using the specified threshold.
    /// - Requires: call setEyeRects before this because historyElementSelected invalidates eyeRects
    func setEyeThresholds(readThresh: Double, interestingThresh: Double, criticalThresh: Double)
    
    /// Returns all information (reading rectangles, proportion) from a document
    /// - Requires: Threshold computation after import
    /// - Returns: Annotated eye rects and proportions (nil if thresholds were not computed)
    func getMarkings() -> (rects: [ReadingRect], pRead: Double, pInteresting: Double, pCritical: Double)?
    
}


/// The history detail controller manager two pdf views, one for an overview and the other for more detailed
/// display.
class HistoryDetailController: NSViewController, HistoryDetailDelegate {
    
    /// SMI Rectangles fetched from event
    private var eyeRects: [EyeRectangle]?
    
    /// Marked rectangles
    private var pageRects: [ReadingRect]?
    
    /// Last opened url
    private var lastUrl: NSURL?
    
    private var requiresThresholdComputation = true

    @IBOutlet weak var pdfOverview: MyPDFOverview!
    @IBOutlet weak var pdfDetail: MyPDFBase!
    
    /// A reading event was selected, display the doc and its rectangles in the pdf views
    func historyElementSelected(tuple: (ev: ReadingEvent, ie: ScientificDocument)) {
        eyeRects = nil
        // check if file exists first (if not, display and error)
        if NSFileManager.defaultManager().fileExistsAtPath(tuple.ie.uri) {
            lastUrl = NSURL(fileURLWithPath: tuple.ie.uri)
            pageRects = tuple.ev.pageRects
            let pdfDoc1 = PDFDocument(URL: lastUrl)
            let pdfDoc2 = PDFDocument(URL: lastUrl)
            pdfOverview.setScaleFactor(0.2)
            pdfOverview.setDocument(pdfDoc1)
            pdfOverview.scrollToBeginningOfDocument(self)
            pdfOverview.markings.setAll(pageRects!)
            pdfDetail.setDocument(pdfDoc2)
            pdfDetail.markings.setAll(pageRects!)
            pdfDetail.autoAnnotate()
            pdfOverview.pdfDetail = pdfDetail
            NSNotificationCenter.defaultCenter().addObserver(pdfOverview, selector: #selector(pdfOverview.pdfDetailHasNewPage(_:)), name: PDFViewPageChangedNotification, object: pdfDetail)
        } else {
            AppSingleton.alertUser("Can't find original file", infoText: tuple.ie.uri)
        }
        requiresThresholdComputation = true
    }
    
    func focusOn(area: FocusArea) {
        self.pdfDetail.focusOn(area)
        self.pdfOverview.focusOn(area)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    func setEyeRects(eyeRects: [EyeRectangle]) {
        self.eyeRects = eyeRects
        let rRects: [ReadingRect] = eyeRects.map({ReadingRect(fromEyeRect: $0, readingClass: .Paragraph)})
        pdfOverview.markings.setAll(rRects)
        dispatch_async(dispatch_get_main_queue()) {
            self.pdfOverview.layoutDocumentView()
            self.pdfOverview.display()
        }
    }
    
    func getPdfBase() -> MyPDFBase? {
        return pdfDetail
    }
    
    func setEyeThresholds(readThresh: Double, interestingThresh: Double, criticalThresh: Double) {
        if let eyeRects = self.eyeRects {
            pageRects = [ReadingRect]()
            for eyeRect in eyeRects {
                var newClass: ReadingClass?
                // use normalized attnVal if present, otherwise force non-normalised attnVal
                let av = (eyeRect.attnVal_n as? Double) ?? eyeRect.attnVal! as Double
                if av > criticalThresh {
                    newClass = .Critical
                } else if av > interestingThresh {
                    newClass = .Interesting
                } else if av >= readThresh {
                    newClass = .Read
                }
                if let nc = newClass {
                    pageRects!.append(ReadingRect(fromEyeRect: eyeRect, readingClass: nc))
                }
            }
            pdfOverview.markings.setAll(pageRects!)
            pdfOverview.markings.flattenRectangles_relevance()
            pdfDetail.markings.setAll(pageRects!)
            pdfDetail.autoAnnotate()
            dispatch_async(dispatch_get_main_queue()) {
                self.pdfOverview.layoutDocumentView()
                self.pdfOverview.display()
                self.pdfDetail.layoutDocumentView()
                self.pdfDetail.display()
            }
            requiresThresholdComputation = false
        } else {
            AppSingleton.alertUser("Nothing to set thresholds for (forgot to import json?).")
            requiresThresholdComputation = true
        }
    }
    
    func getMarkings() -> (rects: [ReadingRect], pRead: Double, pInteresting: Double, pCritical: Double)? {
        if !requiresThresholdComputation {
            let rects = pdfDetail.markings.getAllReadingRects()
            guard let prop = pdfDetail.markings.calculateProportions_relevance() else {
                AppSingleton.alertUser("Failed to retrieve proportions (this should NEVER happen)")
                return nil
            }
            return (rects: rects, pRead: prop.proportionRead, pInteresting: prop.proportionInteresting, pCritical: prop.proportionCritical)
        } else {
            AppSingleton.alertUser("Must compute thresholds before requesting markings")
            return nil
        }
    }
    
    // MARK: - Re-Opening
    
    /// Opens a document corresponding to the current document with the same annotations
    /// as those which are being shown.
    @IBAction func reOpenDocument(sender: AnyObject?) {
        guard let url = lastUrl, rects = pageRects else {
            return
        }
        
        // open document and set computed (ML) marks to manual (click) marks
        NSDocumentController.sharedDocumentController().openDocumentWithContentsOfURL(url, display: true) {
            document, _, _ in
            if let doc = document as? PeyeDocument {
                var newRects = rects.filter({$0.classSource == .ML})
                newRects = newRects.map() {(rect) in var rect = rect; rect.classSource = .Click ; return rect}
                doc.setMarkings(newRects)
            }
        }
    }
    
    @objc override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
        if menuItem.title == "Re-Open" {
            return lastUrl != nil && pageRects != nil
        } else {
            return super.validateMenuItem(menuItem)
        }
    }
    
    /// Focuses the PDFOverview on the page currently shown in the PDFDetail
    @IBAction func overviewCurrentPage(sender: AnyObject) {
        guard let cp = pdfDetail.currentPage(),
                  doc = pdfDetail.document() else {
            return
        }
        
        let cpi = doc.indexForPage(cp)
        pdfOverview.focusOn(FocusArea(forPage: cpi), delay: 0.0)
    }
}

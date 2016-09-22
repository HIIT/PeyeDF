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
    func getPdfBase() -> PDFBase?
    
    /// Tells the delegate that a new item was selected. Resets setEyeRects
    func historyElementSelected(_ tuple: (ev: ReadingEvent, ie: ScientificDocument))
    
    /// Tells the delegate that a new set of eye rectangles should be shown next time
    func setEyeRects(_ eyeRects: [EyeRectangle])
    
    /// Tells the delegate to focus on an area (does it after a delay)
    func focusOn(_ area: FocusArea)
    
    /// Tells the delegate to display the current (communicated via setEyeRects) set of eye rectangles by converting them to
    /// a set of markings (reading rect) using the specified threshold.
    /// - Requires: call setEyeRects before this because historyElementSelected invalidates eyeRects
    func setEyeThresholds(_ readThresh: Double, interestingThresh: Double, criticalThresh: Double)
    
    /// Returns all information (reading rectangles, proportion) from a document.
    /// - Note: These are used for eye tracking (i.e. proportionSeen is not relevant here).
    /// - Requires: Threshold computation after import
    /// - Returns: Annotated eye rects and proportions (nil if thresholds were not computed)
    func getMarkings() -> (rects: [ReadingRect], pRead: Double, pInteresting: Double, pCritical: Double)?
    
}


/// The history detail controller manager two pdf views, one for an overview and the other for more detailed
/// display.
class HistoryDetailController: NSViewController, HistoryDetailDelegate {
    
    /// SMI Rectangles fetched from event
    fileprivate var eyeRects: [EyeRectangle]?
    
    /// Marked rectangles
    fileprivate var pageRects: [ReadingRect]?
    
    /// Last opened url
    fileprivate var lastUrl: URL?
    
    fileprivate var requiresThresholdComputation = true

    @IBOutlet weak var pdfOverview: PDFOverview!
    @IBOutlet weak var pdfDetail: PDFBase!
    
    /// A reading event was selected, display the doc and its rectangles in the pdf views
    func historyElementSelected(_ tuple: (ev: ReadingEvent, ie: ScientificDocument)) {
        eyeRects = nil
        // check if file exists first (if not, display and error)
        if FileManager.default.fileExists(atPath: tuple.ie.uri) {
            lastUrl = URL(fileURLWithPath: tuple.ie.uri)
            pageRects = tuple.ev.pageRects
            let pdfDoc2 = PDFDocument(url: lastUrl!)
            self.pdfDetail.document = pdfDoc2
            pdfOverview.pdfDetail = pdfDetail
            pdfOverview.markings.setAll(pageRects!)
            pdfDetail.markings.setAll(pageRects!)
            pdfDetail.autoAnnotate()
            pdfDetail.refreshAll()
        } else {
            AppSingleton.alertUser("Can't find original file", infoText: tuple.ie.uri)
        }
        requiresThresholdComputation = true
    }
    
    func focusOn(_ area: FocusArea) {
        self.pdfDetail.focusOn(area)
        self.pdfOverview.focusOn(area)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    func setEyeRects(_ eyeRects: [EyeRectangle]) {
        self.eyeRects = eyeRects
        let rRects: [ReadingRect] = eyeRects.map({ReadingRect(fromEyeRect: $0, readingClass: .paragraph)})
        pdfOverview.markings.setAll(rRects)
        pdfOverview.refreshAll()
    }
    
    func getPdfBase() -> PDFBase? {
        return pdfDetail
    }
    
    func setEyeThresholds(_ readThresh: Double, interestingThresh: Double, criticalThresh: Double) {
        if let eyeRects = self.eyeRects {
            pageRects = [ReadingRect]()
            for eyeRect in eyeRects {
                var newClass: ReadingClass?
                // use normalized attnVal if present, otherwise force non-normalised attnVal
                let av = eyeRect.attnVal_n ?? eyeRect.attnVal!
                if av > criticalThresh {
                    newClass = .high
                } else if av > interestingThresh {
                    newClass = .medium
                } else if av >= readThresh {
                    newClass = .low
                }
                if let nc = newClass {
                    pageRects!.append(ReadingRect(fromEyeRect: eyeRect, readingClass: nc))
                }
            }
            pdfOverview.markings.setAll(pageRects!)
            pdfOverview.markings.flattenRectangles_relevance()
            pdfDetail.markings.setAll(pageRects!)
            pdfDetail.autoAnnotate()
            pdfOverview.refreshAll()
            pdfDetail.refreshAll()
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
    @IBAction func reOpenDocument(_ sender: AnyObject?) {
        guard let url = lastUrl, let rects = pageRects else {
            return
        }
        
        // open document and set computed (ML) marks to manual (click) marks
        NSDocumentController.shared().openDocument(withContentsOf: url, display: true) {
            document, _, _ in
            if let doc = document as? PeyeDocument {
                var newRects = rects.filter({$0.classSource == .ml})
                newRects = newRects.map() {(rect) in var rect = rect; rect.classSource = .click ; return rect}
                doc.setMarkings(newRects)
            }
        }
    }
    
    @objc override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.title == "Re-Open" {
            return lastUrl != nil && pageRects != nil
        } else {
            return super.validateMenuItem(menuItem)
        }
    }
    
    /// Focuses the PDFOverview on the page currently shown in the PDFDetail
    @IBAction func overviewCurrentPage(_ sender: AnyObject) {
        guard let cp = pdfDetail.currentPage,
                  let doc = pdfDetail.document else {
            return
        }
        
        let cpi = doc.index(for: cp)
        pdfOverview.focusOn(FocusArea(forPage: cpi), delay: 0.0)
    }
}

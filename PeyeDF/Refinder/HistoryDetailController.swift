//
//  HistoryDetailController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 04/11/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

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
    
    /// Tells the delegate to display the current (communicated via setEyeRects) set of eye rectangles by converting them to
    /// a set of markings (reading rect) using the specified threshold.
    /// - Requires: call setEyeRects before this because historyElementSelected invalidates eyeRects
    func setEyeThresholds(readThresh: Double, interestingThresh: Double, criticalThresh: Double)
}


/// The history detail controller manager two pdf views, one for an overview and the other for more detailed
/// display.
class HistoryDetailController: NSViewController, HistoryDetailDelegate {
    
    private var eyeRects: [EyeRectangle]?

    @IBOutlet weak var pdfOverview: MyPDFOverview!
    @IBOutlet weak var pdfDetail: MyPDFDetail!
    
    /// A reading event was selected, display the doc and its rectangles in the pdf views
    func historyElementSelected(tuple: (ev: ReadingEvent, ie: ScientificDocument)) {
        eyeRects = nil
        // check if file exists first (if not, display and error)
        if NSFileManager.defaultManager().fileExistsAtPath(tuple.ie.uri) {
            let docURL = NSURL(fileURLWithPath: tuple.ie.uri)
            let pdfDoc1 = PDFDocument(URL: docURL)
            let pdfDoc2 = PDFDocument(URL: docURL)
            pdfOverview.setScaleFactor(0.1)
            pdfOverview.setDocument(pdfDoc1)
            pdfOverview.scrollToBeginningOfDocument(self)
            pdfOverview.markings.setAll(tuple.ev.pageRects)
            pdfDetail.setDocument(pdfDoc2)
            pdfDetail.markings.setAll(tuple.ev.pageRects)
            pdfDetail.autoAnnotate()
            pdfOverview.pdfDetail = pdfDetail
        } else {
            AppSingleton.alertUser("Can't find original file", infoText: tuple.ie.uri)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    func setEyeRects(eyeRects: [EyeRectangle]) {
        self.eyeRects = eyeRects
    }
    
    func getPdfBase() -> MyPDFBase? {
        return pdfDetail
    }
    
    func setEyeThresholds(readThresh: Double, interestingThresh: Double, criticalThresh: Double) {
        if let eyeRects = self.eyeRects {
            var newRects = [ReadingRect]()
            for eyeRect in eyeRects {
                var newClass: ReadingClass?
                let attnVal = eyeRect.attnVal! as Double
                if attnVal > criticalThresh {
                    newClass = .Critical
                } else if attnVal > interestingThresh {
                    newClass = .Interesting
                } else if attnVal > readThresh {
                    newClass = .Read
                }
                if let nc = newClass {
                    newRects.append(ReadingRect(fromEyeRect: eyeRect, readingClass: nc))
                }
            }
            pdfOverview.markings.setAll(newRects)
            pdfOverview.markings.flattenRectangles_relevance()
            pdfDetail.markings.setAll(newRects)
            pdfDetail.autoAnnotate()
            dispatch_async(dispatch_get_main_queue()) {
                self.pdfOverview.layoutDocumentView()
                self.pdfOverview.display()
                self.pdfDetail.layoutDocumentView()
                self.pdfDetail.display()
            }
        } else {
            AppSingleton.alertUser("Nothing to set thresholds for (forgot to import json?).")
        }
    }
}

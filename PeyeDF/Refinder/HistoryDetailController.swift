//
//  HistoryDetailController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 04/11/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Cocoa
import Quartz

/// The history detail controller manager two pdf views, one for an overview and the other for more detailed
/// display.
class HistoryDetailController: NSViewController, HistoryDetailDelegate {

    @IBOutlet weak var pdfOverview: MyPDFOverview!
    @IBOutlet weak var pdfDetail: MyPDFDetail!
    
    /// A reading event was selected, display the doc and its rectangles in the pdf views
    func historyElementSelected(tuple: (ev: ReadingEvent, ie: ScientificDocument)) {
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
    
}

//
//  DocumentWindowController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 22/06/15.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Cocoa
import Foundation
import Quartz

class DocumentWindowController: NSWindowController {
    weak var myPdf: MyPDF?

    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Set reference to myPdf for convenience by using references to children of this window
        let splV: NSSplitViewController = self.window?.contentViewController as! NSSplitViewController
        let splV2: DocumentSplitController = splV.childViewControllers[1] as! DocumentSplitController
        myPdf = splV2.myPDFController?.myPDF
        myPdf?.setAutoScales(true)
        
    }
    
    func loadDocument() {

        // Load document and display it
        var pdfDoc: PDFDocument
        
        if let document: NSDocument = self.document as? NSDocument {
            let url: NSURL = document.fileURL!
            let doc:PDFDocument = PDFDocument(URL: url)
            
            pdfDoc = PDFDocument(URL: url)
            myPdf?.setDocument(pdfDoc)
        }
    }
}

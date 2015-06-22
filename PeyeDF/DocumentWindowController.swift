//
//  DocumentWindowController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 22/06/15.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Cocoa
import Foundation
import Quartz.PDFKit

class DocumentWindowController: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        var pdfDoc: PDFDocument
        
        if let document: NSDocument = self.document as? NSDocument {
            let url: NSURL = document.fileURL!
            let doc:PDFDocument = PDFDocument(URL: url)
            
            pdfDoc = PDFDocument(URL: url)
            println(pdfDoc.description)
        }
    }

}

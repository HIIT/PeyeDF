//
//  MetadataWindowController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 06/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Cocoa
import Quartz

class MetadataWindowController: NSWindowController, NSWindowDelegate {

    weak var metadataView: MetadataViewController?
    
    override func windowDidLoad() {
        self.metadataView = self.contentViewController! as? MetadataViewController
    }
    
    /// Overriding this to ask the user if changes should be saved before closing
    func windowShouldClose(sender: AnyObject) -> Bool {
        guard let sender = sender as? NSWindow else {
            return true
        }
        if sender.documentEdited {
            self.metadataView?.saveData()
            return true
        } else {
            return true
        }
    }
    
    func setDoc(pdfDoc: PDFDocument, mainWC: DocumentWindowController) {
        self.window!.title = "Metdata for \(pdfDoc.documentURL().lastPathComponent!)"
        metadataView?.setDoc(pdfDoc, mainWC: mainWC)
    }
    
}

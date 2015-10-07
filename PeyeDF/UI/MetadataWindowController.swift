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
            let myAl = NSAlert()
            myAl.messageText = "Do you want to save the changes to the document's metadata?"
            myAl.addButtonWithTitle("Yes")
            myAl.addButtonWithTitle("No")
            myAl.beginSheetModalForWindow(self.window!) {
                response in
                
                if response == NSAlertFirstButtonReturn {
                    self.metadataView?.saveData()
                }
                self.close()
            }
            return false
        } else {
            return true
        }
    }
    
    func setDoc(pdfDoc: PDFDocument) {
        self.window!.title = "Metdata for \(pdfDoc.documentURL().lastPathComponent!)"
        metadataView?.setDoc(pdfDoc)
    }
    
}

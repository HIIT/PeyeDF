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

/// Manages the "Document Window", which comprises two split views, one inside the other
class DocumentWindowController: NSWindowController, SideCollapseToggleDelegate {
    
    weak var myPdf: MyPDF?
    weak var docSplitController: DocumentSplitController?

    // MARK: Thumbnail side expand / reduce
    
    @IBOutlet weak var thumbTB: NSToolbarItem!
    @IBAction func showSide(sender: NSToolbarItem) {
        docSplitController?.toggleThumbSide()
    }
    
    func sideCollapseAction(wasCollapsed: Bool) {
        if wasCollapsed {
            thumbTB.image = NSImage(named: PeyeConstants.thumbButton_UP)
        } else {
            thumbTB.image = NSImage(named: PeyeConstants.thumbButton_DOWN)
        }
    }
    
    // MARK: Initialization
    
    override func windowDidLoad() {
        super.windowDidLoad()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowIsMain:", name: NSWindowDidBecomeMainNotification, object: self.window)
    
        // Set reference to myPdf for convenience by using references to children of this window
        let splV: NSSplitViewController = self.window?.contentViewController as! NSSplitViewController
        docSplitController = splV.childViewControllers[1] as? DocumentSplitController
        docSplitController?.sideCollapseDelegate = self
        myPdf = docSplitController?.myPDFSideController?.myPDF
        myPdf?.setAutoScales(true)
        
    }
    
    @objc func windowIsMain(notification: NSNotification) {
        dispatch_async(dispatch_get_main_queue()) {
            NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.documentChangeNotification, object: self.document)
        }
    }
    
    /// Loads the PDF document. Must be called after setting current document's URL.
    /// Sends a notification that the document has been loaded, with the document as object
    func loadDocument() {
        // Load document and display it
        var pdfDoc: PDFDocument
        
        if let document: NSDocument = self.document as? NSDocument {
            let url: NSURL = document.fileURL!
            let doc:PDFDocument = PDFDocument(URL: url)
            
            pdfDoc = PDFDocument(URL: url)
            myPdf?.setDocument(pdfDoc)
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.documentChangeNotification, object: self.document)
            }
        }
    }
}

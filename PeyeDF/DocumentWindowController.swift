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
    var debugController: DebugController?
    var debugWindowController: NSWindowController?
    @IBOutlet weak var docStatus: NSToolbarItem!

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
    
    // MARK: Debug functions
    
    @IBAction func thisDocMdata(sender: AnyObject) {
        if let mainWin = NSApplication.sharedApplication().mainWindow {
            let peyeDoc: PeyeDocument = NSDocumentController.sharedDocumentController().documentForWindow(mainWin) as! PeyeDocument
            let myAl = NSAlert()
            
            
            var allTextHead = "** NO TEXT FOUND **"
            if let aText = peyeDoc.trimmedText {  // we assume no text if this is nil
                let ei = advance(aText.startIndex, 500)
                allTextHead = aText.substringToIndex(ei)
            }
            myAl.messageText = "Filename: \(peyeDoc.filename)\nTitle: \(peyeDoc.title)\nAuthor(s):\(peyeDoc.authors)"
            myAl.informativeText = "All text (first 500 chars):\n" + allTextHead
            myAl.beginSheetModalForWindow(mainWin, completionHandler: nil)
        }
    }
    
    
    // MARK: Saving
    
    func saveDocument(sender: AnyObject) {
        saveDocumentAs(sender)
    }
    
    func saveDocumentAs(sender: AnyObject) {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["pdf", "PDF"]
        if panel.runModal() == NSFileHandlingPanelOKButton {
            myPdf?.document().writeToURL(panel.URL)
            let documentController = NSDocumentController.sharedDocumentController() as! NSDocumentController
            documentController.openDocumentWithContentsOfURL(panel.URL!, display: true) { _ in
                // empty, nothing else to do (NSDocumentController will automacally link URL to NSDocument (pdf file)
            }
        }
    }
    
    // MARK: Initialization
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Set reference to myPdf for convenience by using references to children of this window
        let splV: NSSplitViewController = self.window?.contentViewController as! NSSplitViewController
        docSplitController = splV.childViewControllers[1] as? DocumentSplitController
        docSplitController?.sideCollapseDelegate = self
        myPdf = docSplitController?.myPDFSideController?.myPDF
        
        myPdf?.setAutoScales(true)
        
        // Create debug window
        debugWindowController = AppSingleton.storyboard.instantiateControllerWithIdentifier("DebugWindow") as? NSWindowController
        debugWindowController?.showWindow(self)
        debugController = (debugWindowController?.contentViewController as! DebugController)
        
        // Get notifications from managed window (to be later dispatched to singleton)
        debugController?.setUpMonitors(myPdf!, docWindow: self.window!)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowWantsMain:", name: NSWindowDidBecomeMainNotification, object: self.window)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowWantsClose:", name: NSWindowWillCloseNotification, object: self.window)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowOcclusionChange:", name: NSWindowDidChangeOcclusionStateNotification, object: self.window)
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
            //dispatch_async(dispatch_get_main_queue()) {
            //    NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.documentChangeNotification, object: self.document)
            //}
        
            // Put metadata into NSDocument subclass for convenience
            let peyeDoc = self.document as! PeyeDocument
            let docAttrib = pdfDoc.documentAttributes()
            if let title: AnyObject = docAttrib[PDFDocumentTitleAttribute] {
                peyeDoc.title = title as! String
            }
            if let auth: AnyObject = docAttrib[PDFDocumentAuthorAttribute] {
                peyeDoc.authors = auth as! String
            }
            var trimmedText = pdfDoc.string()
            trimmedText = trimmedText.stringByReplacingOccurrencesOfString("\u{fffc}", withString: "")
            trimmedText = trimmedText.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) // get trimmed version of all text
            trimmedText = trimmedText.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet()) // trim newlines
            trimmedText = trimmedText.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) // trim again
            if count(trimmedText) > 5 {  // we assume the document does contain useful text if there are more than 5 characters remaining
                peyeDoc.trimmedText = trimmedText
                myPdf?.containsRawString = true
                docStatus.image = NSImage(named: "NSStatusAvailable")
            } else {
                docStatus.image = NSImage(named: "NSStatusPartiallyAvailable")
            }
        }
    }
    
    // MARK: Receving and dispatching notifications from managed window
    
    @objc func windowWantsMain(notification: NSNotification) {
        NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.documentChangeNotification, object: self.document)
    }
    
    @objc func windowOcclusionChange(notification: NSNotification) {
        NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.occlusionChangeNotification, object: self.window)
    }
    
    @objc func windowWantsClose(notification: NSNotification) {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidBecomeMainNotification, object: self.window)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowWillCloseNotification, object: self.window)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidChangeOcclusionStateNotification, object: self.window)
        debugController?.unSetMonitors(myPdf!, docWindow: self.window!)
        debugController?.view.window?.close()
        myPdf?.setDocument(nil)
    }
}

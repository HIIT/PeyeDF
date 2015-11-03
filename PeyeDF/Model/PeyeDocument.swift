//
//  MyDocument.swift
//  PeyeDF
//
//  Created by Marco Filetti on 18/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa
import Quartz

/// Implementation of a (PDF) Document (partially?) following NSDocument's guidelines
class PeyeDocument: NSDocument {
    
    /// Reference to underlying PDFDocument. Set after loading document by window controller.
    weak var pdfDoc: PDFDocument?
    
    // MARK: - DiMe related
    
    // MARK: - NSDocument overrides
    
    override init() {
        super.init()
    }

    override func windowControllerDidLoadNib(aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
        // Add any code here that needs to be executed once the windowController has loaded the document's window.
    }

    override class func autosavesInPlace() -> Bool {
        return false
    }
    
    /// Creates window controllers and automatically calls loadDocument()
    override func makeWindowControllers() {
        let storyboard = AppSingleton.mainStoryboard
        
        let windowController = storyboard.instantiateControllerWithIdentifier("Document Window Controller") as! DocumentWindowController
        self.addWindowController(windowController)
        AppSingleton.appDelegate.openPDFs++
        windowController.loadDocument()
        windowController.shouldCloseDocument = true // tell to automaticall close document when closing window
    }
    
    /// Saving document to a given url
    override func writeToURL(url: NSURL, ofType type: String) throws {
        if type == "PeyeDF" {
            let wincontroller = self.windowControllers[0] as! DocumentWindowController
            wincontroller.myPdf?.document().writeToURL(url)
            return
        } else {
            // We don't know what Cocoa is attempting to save, throw some error
            throw NSError(domain: NSOSStatusErrorDomain, code: NSURLErrorCannotWriteToFile, userInfo: nil)
        }
    }
    
    /// Does nothing, assumes we can only open allowed documents (PDFs) in the first place
    override func readFromURL(url: NSURL, ofType typeName: String) throws {
        // AppSingleton.log.debug("Opening  \(url.description)")
    }
}
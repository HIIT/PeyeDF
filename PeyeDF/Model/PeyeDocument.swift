//
//  MyDocument.swift
//  PeyeDF
//
//  Created by Marco Filetti on 18/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa

/// Implementation of a (PDF) Document (partially?) following NSDocument's guidelines
class PeyeDocument: NSDocument {
    
    var title: String
    var authors: String
    var filename: String
    
    /// Initially is set to a hash of the url. After loading the document, it is set to the hash of the whole file plain text content (if any)
    var sha1: String?
    
    /// Contains all plain text from PDF, with extra characters (such as whitespace) trimmed
    var trimmedText: String?
    
    // MARK: DiMe related
    
    // MARK: NSDocument overrides
    
    override init() {
        title = "N/A"
        authors = "N/A"
        filename = "N/A"
        
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
        let storyboard = AppSingleton.storyboard
        
        let windowController = storyboard.instantiateControllerWithIdentifier("Document Window Controller") as! DocumentWindowController
        self.addWindowController(windowController)
        windowController.loadDocument()
        windowController.shouldCloseDocument = true // tell to automaticall close document when closing window
    }
    
    override func dataOfType(typeName: String, error outError: NSErrorPointer) -> NSData? {
        // Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
        outError.memory = NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        return nil
    }
    
    /// Always returns true, assumes we can only open allowed documents (PDFs) in the first place
    override func readFromURL(url: NSURL, ofType typeName: String, error outError: NSErrorPointer) -> Bool {
        AppSingleton.log.debug("Opening " + url.description)
        filename = url.lastPathComponent!
        sha1 = url.path!.sha1()
        return true
    }
}
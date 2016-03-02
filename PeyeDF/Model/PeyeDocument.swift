//
// Copyright (c) 2015 Aalto University
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

import Foundation
import Cocoa
import Quartz

/// Implementation of a (PDF) Document (partially?) following NSDocument's guidelines
class PeyeDocument: NSDocument {
    
    /// Reference to underlying PDFDocument. Set after loading document by window controller.
    weak var pdfDoc: PDFDocument?
    
    
    // MARK: - Convenience
    
    /// Open this PDF in preview
    @IBAction func openInPreview(sender: AnyObject?) {
        NSWorkspace.sharedWorkspace().openURLs([self.fileURL!], withAppBundleIdentifier: "com.apple.Preview", options: NSWorkspaceLaunchOptions(), additionalEventParamDescriptor: nil, launchIdentifiers: nil)
    }
    
    /// Convenience function to call the focusOn method of this document's pdfReader.
    func focusOn(f: FocusArea) {
        guard windowControllers.count == 1 else {
            return
        }
        guard let wc = windowControllers[0] as? DocumentWindowController else {
            return
        }
        
        wc.pdfReader?.focusOn(f)
    }
    
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
        windowController.loadDocument()
        windowController.shouldCloseDocument = true // tell to automatically close document when closing window
    }
    
    /// Saving document to a given url
    override func writeToURL(url: NSURL, ofType type: String) throws {
        if type == "PeyeDF" {
            let wincontroller = self.windowControllers[0] as! DocumentWindowController
            wincontroller.pdfReader?.document().writeToURL(url)
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
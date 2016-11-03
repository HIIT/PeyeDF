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

enum RefuseToOpenError: Error {
    case maxOneAllowed
}

/// Implementation of a (PDF) Document (partially?) following NSDocument's guidelines
class PeyeDocument: NSDocument {
    
    override var isDocumentEdited: Bool { get {
        if UserDefaults.standard.object(forKey: PeyeConstants.prefAskToSaveOnClose) as! NSNumber == 0 {
            return false
        } else {
            return super.isDocumentEdited
        }
    } }
    
    var wereAnnotationsAdded: Bool { get {
        return super.isDocumentEdited
    } }
    
    /// Reference to underlying PDFDocument. Set after loading document by window controller.
    weak var pdfDoc: PDFDocument?
    
    // MARK: - Convenience
    
    /// Sets all annotations to a given set of reading rects.
    /// - Note: Only rects with classSource .Click will be added
    func setMarkings(_ newRects: [ReadingRect]) {
        guard windowControllers.count == 1 else {
            return
        }
        guard let wc = windowControllers[0] as? DocumentWindowController else {
            return
        }
        
        wc.pdfReader?.markAndAnnotateBulk(newRects)
    }
    
    /// Open this PDF in preview
    @IBAction func openInPreview(_ sender: AnyObject?) {
        NSWorkspace.shared().open([self.fileURL!], withAppBundleIdentifier: "com.apple.Preview", options: NSWorkspaceLaunchOptions(), additionalEventParamDescriptor: nil, launchIdentifiers: nil)
        if self.windowControllers.count == 1, let wc = self.windowControllers[0] as? DocumentWindowController {
            wc.window!.performClose(self)
        }
    }
    
    /// Convenience function to call the focusOn method of this document's pdfReader.
    func focusOn(_ f: FocusArea) {
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

    override func windowControllerDidLoadNib(_ aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
        // Add any code here that needs to be executed once the windowController has loaded the document's window.
    }

    override class func autosavesInPlace() -> Bool {
        return false
    }
    
    /// Creates window controllers and automatically calls loadDocument()
    override func makeWindowControllers() {
        let storyboard = AppSingleton.mainStoryboard
        let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as! DocumentWindowController
        
        // if eye tracker is NOT active, cascade window, otherwise constrain to center of screen
        if !(AppSingleton.eyeTracker?.available ?? false) {
            // cascade window
            AppSingleton.nextDocWindowPos = windowController.window!.cascadeTopLeft(from: AppSingleton.nextDocWindowPos)
        } else {
            // constrain window
            if let window = windowController.window, let screen = window.screen {
                let shrankRect = DocumentWindow.getConstrainingRect(forScreen: screen)
                let intersectedRect = shrankRect.intersection(window.frame)
                if intersectedRect != window.frame {
                    window.setFrame(intersectedRect, display: true)
                }
            }
        }
        
        self.addWindowController(windowController)
        
        windowController.loadDocument()
        windowController.shouldCloseDocument = true // tell to automatically close document when closing window
    }
    
    /// Saving document to a given url
    override func write(to url: URL, ofType type: String) throws {
        if type == "PeyeDF" {
            let wincontroller = self.windowControllers[0] as! DocumentWindowController
            wincontroller.pdfReader?.document!.write(to: url)
            return
        } else {
            // We don't know what Cocoa is attempting to save, throw some error
            throw NSError(domain: NSOSStatusErrorDomain, code: NSURLErrorCannotWriteToFile, userInfo: nil)
        }
    }
    
    /// Does nothing, assumes we can only open allowed documents (PDFs) in the first place.
    override func read(from url: URL, ofType typeName: String) throws {
    }
    
}

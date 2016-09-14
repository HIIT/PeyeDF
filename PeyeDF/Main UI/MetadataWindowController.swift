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

import Cocoa
import Quartz

class MetadataWindowController: NSWindowController, NSWindowDelegate {

    weak var metadataView: MetadataViewController?
    
    override func windowDidLoad() {
        self.metadataView = self.contentViewController! as? MetadataViewController
    }
    
    /// Overriding this to ask the user if changes should be saved before closing
    func windowShouldClose(_ sender: Any) -> Bool {
        guard let sender = sender as? NSWindow else {
            return true
        }
        if sender.isDocumentEdited {
            self.metadataView?.saveData()
            return true
        } else {
            return true
        }
    }
    
    func setDoc(_ pdfDoc: PDFDocument, mainWC: DocumentWindowController) {
        self.window!.title = "Metdata for \(pdfDoc.documentURL!.lastPathComponent)"
        metadataView?.setDoc(pdfDoc, mainWC: mainWC)
    }
    
}

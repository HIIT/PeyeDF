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

class MetadataViewController: NSViewController {
    
    fileprivate weak var pdfDoc: PDFDocument?
    fileprivate weak var mainCont: DocumentWindowController?

    @IBOutlet weak var keywordArrayController: NSArrayController!
    
    var keywordArray: [String]!
    
    var initialTitle: String?
    var initialSubject: String?
    var initialAuthor: String?
    var initialKeywords: String?
    
    @IBOutlet weak var titleField: NSTextField!
    @IBOutlet weak var subjectField: NSTextField!
    @IBOutlet weak var authorField: NSTextField!
    @IBOutlet weak var keywordsField: NSTextField!
    
    func setDoc(_ pdfDoc: PDFDocument, mainWC: DocumentWindowController) {
        self.pdfDoc = pdfDoc
        self.mainCont = mainWC
        
        if let title = pdfDoc.getTitle() {
            titleField.stringValue = title
        }
        if let subject = pdfDoc.getSubject() {
            subjectField.stringValue = subject
        }
        if let author = pdfDoc.getAuthor() {
            authorField.stringValue = author
        }
        if let keywords = pdfDoc.getKeywords() {
            keywordsField.stringValue = keywords
        }
        initialTitle = titleField.stringValue
        initialAuthor = authorField.stringValue
        initialSubject = subjectField.stringValue
        initialKeywords = keywordsField.stringValue
        checkForChanges(nil)
    }
    
    func saveData() {
        var dirty = false
        if initialTitle != titleField.stringValue {
            if titleField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces).characters.count > 0 {
                let trimVal = titleField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces)
                pdfDoc!.setTitle(trimVal)
                dirty = true
            }
        }
        if initialAuthor != authorField.stringValue {
            if authorField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces).characters.count > 0 {
                let trimVal = authorField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces)
                pdfDoc!.setAuthor(trimVal)
                dirty = true
            }
            
        }
        if initialSubject != subjectField.stringValue {
            if subjectField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces).characters.count > 0 {
                let trimVal = subjectField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces)
                pdfDoc!.setSubject(trimVal)
                dirty = true
            }
            
        }
        if initialKeywords != keywordsField.stringValue {
            if keywordsField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces).characters.count > 0 {
                let trimVal = keywordsField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces)
                pdfDoc!.setKeywords(trimVal)
                dirty = true
            }
        }
        if dirty {
            mainCont!.setDocumentEdited(true)
            (mainCont!.document as! NSDocument).updateChangeCount(NSDocumentChangeType.changeDone)
        }
    }
    
    /// To be called after editing values, to make sure window closing should ask for saving
    @IBAction fileprivate func checkForChanges(_ sender: AnyObject?) {
        if initialTitle == titleField.stringValue &&
           initialAuthor == authorField.stringValue &&
           initialSubject == subjectField.stringValue &&
           initialKeywords == keywordsField.stringValue {
            self.view.window!.isDocumentEdited = false
        } else {
            self.view.window!.isDocumentEdited = true
        }
    }
    
}

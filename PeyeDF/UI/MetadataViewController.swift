//
//  MetadataViewController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 06/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Cocoa
import Quartz

class MetadataViewController: NSViewController {
    
    private weak var pdfDoc: PDFDocument?

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
    
    @IBOutlet weak var plaintextLabel: NSTextField!
    
    func setDoc(pdfDoc: PDFDocument) {
        self.pdfDoc = pdfDoc
        
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
        if let plainText = pdfDoc.getText() {
            plaintextLabel.stringValue = plainText
        }
        initialTitle = titleField.stringValue
        initialAuthor = authorField.stringValue
        initialSubject = subjectField.stringValue
        initialKeywords = keywordsField.stringValue
        checkForChanges(nil)
    }
    
    func saveData() {
        if initialTitle != titleField.stringValue {
            if titleField.stringValue.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()).characters.count > 0 {
                let trimVal = titleField.stringValue.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                pdfDoc!.setTitle(trimVal)
            }
        }
        if initialAuthor != authorField.stringValue {
            if authorField.stringValue.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()).characters.count > 0 {
                let trimVal = authorField.stringValue.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                pdfDoc!.setAuthor(trimVal)
            }
            
        }
        if initialSubject != subjectField.stringValue {
            if subjectField.stringValue.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()).characters.count > 0 {
                let trimVal = subjectField.stringValue.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                pdfDoc!.setSubject(trimVal)
            }
            
        }
        if initialKeywords != keywordsField.stringValue {
            if keywordsField.stringValue.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()).characters.count > 0 {
                let trimVal = keywordsField.stringValue.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                pdfDoc!.setKeywords(trimVal)
            }
        }
    }
    
    /// To be called after editing values, to make sure window closing should ask for saving
    @IBAction private func checkForChanges(sender: AnyObject?) {
        if initialTitle == titleField.stringValue &&
           initialAuthor == authorField.stringValue &&
           initialSubject == subjectField.stringValue &&
           initialKeywords == keywordsField.stringValue {
            self.view.window!.documentEdited = false
        } else {
            self.view.window!.documentEdited = true
        }
    }
    
}

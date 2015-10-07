//
//  PDFDocumentExtensions.swift
//  PeyeDF
//
//  Created by Marco Filetti on 07/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Foundation
import Quartz

extension PDFDocument {
    
    // MARK: - Getters
    
    /// Returns a trimmed plain text of the data contained in the document, nil not present
    func getText() -> String? {
        
        var trimmedText = string()
        trimmedText = trimmedText.stringByReplacingOccurrencesOfString("\u{fffc}", withString: "")
        trimmedText = trimmedText.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) // get trimmed version of all text
        trimmedText = trimmedText.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet()) // trim newlines
        trimmedText = trimmedText.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) // trim again
        if trimmedText.characters.count > 5 {  // we assume the document does contain useful text if there are more than 5 characters remaining
            return trimmedText
        } else {
            return nil
        }
    }
    
    /// Gets the title from the document metadata, returns nil if not present
    func getTitle() -> String? {
        let docAttrib = documentAttributes()
        if let title: AnyObject = docAttrib[PDFDocumentTitleAttribute] {
            return (title as! String)
        } else {
            return nil
        }
    }
    
    /// Gets the author(s) from the document metadata, returns nil if not present
    func getAuthor() -> String? {
        let docAttrib = documentAttributes()
        if let author: AnyObject = docAttrib[PDFDocumentAuthorAttribute] {
            return (author as! String)
        } else {
            return nil
        }
    }
    
    /// Gets the subject from the document metadata, returns nil if not present
    func getSubject() -> String? {
        let docAttrib = documentAttributes()
        if let subject: AnyObject = docAttrib[PDFDocumentSubjectAttribute] {
            return (subject as! String)
        } else {
            return nil
        }
    }
    
    /// Gets the keywods from the document metadata, returns nil if not present
    func getKeywords() -> String? {
        let docAttrib = documentAttributes()
        if let keywords: AnyObject = docAttrib[PDFDocumentKeywordsAttribute] {
            return (keywords as! String)
        } else {
            return nil
        }
    }
    
    // MARK: - Setters
    
    func setTitle(newTitle: String) {
        var docAttrib = documentAttributes()
        docAttrib[PDFDocumentTitleAttribute] = newTitle
        setDocumentAttributes(docAttrib)
    }
    
    func setSubject(newSubject: String) {
        var docAttrib = documentAttributes()
        docAttrib[PDFDocumentSubjectAttribute] = newSubject
        setDocumentAttributes(docAttrib)
    }
    
    func setAuthor(newAuthor: String) {
        var docAttrib = documentAttributes()
        docAttrib[PDFDocumentAuthorAttribute] = newAuthor
        setDocumentAttributes(docAttrib)
    }
    
    func setKeywords(newKeywords: String) {
        var docAttrib = documentAttributes()
        docAttrib[PDFDocumentKeywordsAttribute] = newKeywords
        setDocumentAttributes(docAttrib)
    }
}
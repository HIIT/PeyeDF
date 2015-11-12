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
    
    /// Returns all keywords in an array, useful for DiMe.
    /// Keywords can be separated by ";" or ","
    func getKeywordsAsArray() -> [String]? {
        guard let keyws = getKeywords() else {
            return nil
        }
        
        var retVal: [String]?
        if keyws.containsChar(";") {
            retVal = keyws.split(";")
        } else if keyws.containsChar(",") {
            retVal = keyws.split(",")
        } else {
            retVal = [keyws]
        }
        if let retVal = retVal {
            return retVal
        } else {
            return nil
        }
    }
    
    /// Returns all authors as an array of person, useful for DiMe.
    /// Authors can be only separated by ";"
    func getAuthorsAsArray() -> [Person]? {
        guard let auths = getAuthor() else {
            return nil
        }
        
        var retVal = [Person]()
        if auths.containsChar(";") {
            if let splitStr = auths.split(";") {
                for subStr in splitStr {
                    if let newPerson = Person(fromString: subStr) {
                        retVal.append(newPerson)
                    }
                }
            }
        } else {
            if let newPerson = Person(fromString: auths) {
                retVal.append(newPerson)
            }
        }
        
        if retVal.count > 0 {
            return retVal
        } else {
            return nil
        }
    }
    
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
            // some times keywords are in an array
            // other times keywords are all contained in the first element of the array as a string
            // other times they are a string
            if let keywarray = keywords as? [AnyObject] {
                if keywarray.count == 1 {
                    return (keywarray[0] as? String)
                } else {
                    var outStr = ""
                    outStr += keywarray[0] as? String ?? ""
                    for nkw in keywarray {
                        outStr += "; "
                        outStr +=  nkw as? String ?? ""
                    }
                    if outStr == "" {
                        return nil
                    } else {
                        return outStr
                    }
                }
            } else {
                return keywords as? String
            }
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

extension PDFSelection {
    
    /// Returns true if two selections are "practically the same".
    /// Empty selections are always equal.
    func equalsTo(rhs: PDFSelection) -> Bool {
        if self.pages().count == 0 {
            return true
        } else if self.pages().count != rhs.pages().count {
            return false
        }
        for p in self.pages() {
            let pp = p as! PDFPage
            if self.boundsForPage(pp) != rhs.boundsForPage(pp) {
                return false
            }
        }
        return true
    }
}
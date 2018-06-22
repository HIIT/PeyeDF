//
// Copyright (c) 2018 University of Helsinki, Aalto University
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
import Quartz
import os.log

extension PDFDocument {
    
    /// Returns true if the two readingrects are "far" from each other
    func areFar(_ a: ReadingRect, _ b: ReadingRect) -> Bool {
        if a.pageIndex == b.pageIndex {
            if let page = getPage(atIndex: a.pageIndex as Int) {
                return !page.rectsNearby(a.rect, b.rect)
            }
        }
        return true
    }
    
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
    /// - Warning: Takes time and memory for big documents, better to asynchronise this
    func getText() -> String? {
        var trimmedText = string
        trimmedText = trimmedText!.replacingOccurrences(of: "\u{fffc}", with: "")
        trimmedText = trimmedText!.trimmingCharacters(in: CharacterSet.whitespaces) // get trimmed version of all text
        trimmedText = trimmedText!.trimmingCharacters(in: CharacterSet.newlines) // trim newlines
        trimmedText = trimmedText!.trimmingCharacters(in: CharacterSet.whitespaces) // trim again
        if trimmedText!.count > 5 {  // we assume the document does contain useful text if there are more than 5 characters remaining
            return trimmedText
        } else {
            return nil
        }
    }
    
    /// Gets the title from the document metadata, returns nil if not present
    func getTitle() -> String? {
        let docAttrib = documentAttributes
        if let title: String = docAttrib![PDFDocumentAttribute.titleAttribute] as? String , title.trimmed().count > 0 {
            return title.trimmed()
        } else {
            return nil
        }
    }
    
    /// Gets the author(s) from the document metadata, returns nil if not present
    func getAuthor() -> String? {
        let docAttrib = documentAttributes
        if let author: Any = docAttrib![PDFDocumentAttribute.authorAttribute] {
            return (author as! String)
        } else {
            return nil
        }
    }
    
    /// Gets the subject from the document metadata, returns nil if not present
    func getSubject() -> String? {
        let docAttrib = documentAttributes
        if let subject: Any = docAttrib![PDFDocumentAttribute.subjectAttribute] {
            return (subject as! String)
        } else {
            return nil
        }
    }
    
    /// Gets the keywods from the document metadata, returns nil if not present
    func getKeywords() -> String? {
        let docAttrib = documentAttributes
        if let keywords: Any = docAttrib![PDFDocumentAttribute.keywordsAttribute] {
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
    
    // MARK: - Auto-Metadata
    
    /// **Synchronously** attempt to auto-set metadata using crossref.
    /// - Attention: Do not call this from main thread (blocks while waiting for an answer).
    /// - Returns: The json found with crossref, or nil if the operation failed.
    func autoCrossref() -> JSON? {
        
        guard !Thread.isMainThread else {
            if #available(OSX 10.12, *) {
                os_log("Called from main thread, exiting", type: .error)
            }
            return nil
        }
        
        // Try to find doi
        var _doi: String? = nil
        
        guard let pageString = self.page(at: 0)!.string else {
            return nil
        }
        
        let doiSearches = ["doi ", "doi:"]
        for doiS in doiSearches {
            let range = pageString.range(of: doiS, options: NSString.CompareOptions.caseInsensitive, range: nil, locale: nil)
            
            if let upperBound = range?.upperBound {
                let s = String(pageString[upperBound...]).trimmed()
                if let doiChunk = s.firstChunk() , doiChunk.count >= 5 {
                    _doi = doiChunk
                    break
                }
            }
        }
        
        // If doi was found, use the crossref api to auto-set metadata
        guard let doi = _doi else {
            return nil
        }
        
        var foundJson: JSON?
        let sema = DispatchSemaphore(value: 0)
        
        CrossRefSession.fetch(doi: doi) {
            json in
            if let json = json {
                if let status = json["status"].string , status == "ok" {
                    if let title = json["message"]["title"][0].string {
                        self.setTitle(title)
                    }
                    if let subj = json["message"]["container-title"][0].string {
                        self.setSubject(subj)
                    }
                    if let auths = json["message"]["author"].array {
                        let authString = auths.map({$0["given"].stringValue + " " + $0["family"].stringValue}).joined(separator: "; ")
                        self.setAuthor(authString)
                    }
                    foundJson = json
                }
            }
            sema.signal()
        }
        
        // wait five seconds
        let waitTime = DispatchTime.now() + 5.0
        guard sema.wait(timeout: waitTime) != .timedOut else {
            return nil
        }
        
        return foundJson
    }
    
    /// Returns the string corresponding to the block with the largest font on the first page.
    /// Returns nil if no information could be found or if two or more blocks have the same largest size.
    func guessTitle() -> String? {
        let astring = page(at: 0)!.attributedString
        
        let fullRange = NSMakeRange(0, astring!.length)

        var textInfo = [(size: CGFloat, range: NSRange)]()

        astring!.enumerateAttribute(NSAttributedString.Key.font, in: fullRange, options: NSAttributedString.EnumerationOptions()) {
            obj, range, stop in
            if let font = obj as? NSFont {
                textInfo.append((size: font.pointSize, range: range))
            }
        }

        textInfo.sort(by: {$0.size > $1.size})

        if textInfo.count >= 2 && textInfo[0].size > textInfo[1].size {
            return (astring!.string as NSString).substring(with: textInfo[0].range)
        } else {
            return nil
        }
    }
    
    // MARK: - Setters
    
    func setTitle(_ newTitle: String) {
        var docAttrib = documentAttributes
        docAttrib![PDFDocumentAttribute.titleAttribute] = newTitle
        documentAttributes = docAttrib
    }
    
    func setSubject(_ newSubject: String) {
        var docAttrib = documentAttributes
        docAttrib![PDFDocumentAttribute.subjectAttribute] = newSubject
        documentAttributes = docAttrib
    }
    
    func setAuthor(_ newAuthor: String) {
        var docAttrib = documentAttributes
        docAttrib![PDFDocumentAttribute.authorAttribute] = newAuthor
        documentAttributes = docAttrib
    }
    
    func setKeywords(_ newKeywords: String) {
        var docAttrib = documentAttributes
        docAttrib![PDFDocumentAttribute.keywordsAttribute] = newKeywords
        documentAttributes = docAttrib
    }
    
    /**
     Get the page at the specified index (unlike the PDFKit function, returns nil
     if the index is out of bounds, but logs a warning).
     */
    public func getPage(atIndex index: Int) -> PDFPage? {
        if index < 0 || index >= self.pageCount {
            return nil
        } else {
            return self.page(at: index)
        }
    }
}

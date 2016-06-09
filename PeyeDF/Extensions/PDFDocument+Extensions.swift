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
import Quartz
import Alamofire

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
    /// - Warning: Takes time and memory for big documents, better to asynchronise this
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
        if let title: String = docAttrib[PDFDocumentTitleAttribute] as? String where title.trimmed().characters.count > 0 {
            return title.trimmed()
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
    
    // MARK: - Auto-Metadata
    
    /// **Synchronously** attempt to auto-set metadata using crossref.
    /// - Attention: Do not call this from main thread (blocks while waiting for an answer).
    /// - Returns: The json found with crossref, or nil if the operation failed.
    func autoCrossref() -> JSON? {
        // Try to find doi
        var _doi: String? = nil
        
        guard let pageString = self.pageAtIndex(0).string() else {
            return nil
        }
        
        let doiSearches = ["doi ", "doi:"]
        for doiS in doiSearches {
            let _range = pageString.rangeOfString(doiS, options: NSStringCompareOptions.CaseInsensitiveSearch, range: nil, locale: nil)
            
            if let r = _range, last = r.last {
                let s = pageString.substringFromIndex(last.advancedBy(1)).trimmed()
                if let doiChunk = s.firstChunk() where doiChunk.characters.count >= 5 {
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
        let sema = dispatch_semaphore_create(0)
        
        Alamofire.request(.GET, "http://api.crossref.org/works/\(doi)").responseJSON() {
            response in
            if let resp = response.result.value where response.result.isSuccess {
                let _json = JSON(resp)
                if let status = _json["status"].string where status == "ok" {
                    if let title = _json["message"]["title"][0].string {
                        self.setTitle(title)
                    }
                    if let subj = _json["message"]["container-title"][0].string {
                        self.setSubject(subj)
                    }
                    if let auths = _json["message"]["author"].array {
                        let authString = auths.map({$0["given"].stringValue + " " + $0["family"].stringValue}).joinWithSeparator("; ")
                        self.setAuthor(authString)
                    }
                    foundJson = _json
                }
            }
            dispatch_semaphore_signal(sema)
        }
        
        // wait five seconds
        let waitTime = dispatch_time(DISPATCH_TIME_NOW, Int64(5.0 * Float(NSEC_PER_SEC)))
        if dispatch_semaphore_wait(sema, waitTime) != 0 {
            AppSingleton.log.warning("Crossref request timed out")
        }
        
        return foundJson
    }
    
    /// Returns the string corresponding to the block with the largest font on the first page.
    /// Returns nil if no information could be found or if two or more blocks have the same largest size.
    func guessTitle() -> String? {
        let astring = pageAtIndex(0).attributedString()
        
        let fullRange = NSMakeRange(0, astring.length)

        var textInfo = [(size: CGFloat, range: NSRange)]()

        astring.enumerateAttribute(NSFontAttributeName, inRange: fullRange, options: NSAttributedStringEnumerationOptions()) {
            obj, range, stop in
            if let font = obj as? NSFont {
                textInfo.append(size: font.pointSize, range: range)
            }
        }

        textInfo.sortInPlace({$0.size > $1.size})

        if textInfo.count >= 2 && textInfo[0].size > textInfo[1].size {
            return (astring.string as NSString).substringWithRange(textInfo[0].range)
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
    
    /**
     Get the page at the specified index (unlike the PDFKit function, returns nil
     if the index is out of bounds, but logs a warning).
     */
    public func getPage(atIndex index: Int) -> PDFPage? {
        if index < 0 || index >= self.pageCount() {
            AppSingleton.log.warning("Attempted to retrieve a page at index \(index), while the document has \(self.pageCount()) pages.")
            return nil
        } else {
            return self.pageAtIndex(index)
        }
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
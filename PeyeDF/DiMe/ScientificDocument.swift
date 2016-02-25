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

class ScientificDocument: DocumentInformationElement {
    
    var booktitle: String?
    var year: Int?
    var firstPage: Int?
    var lastPage: Int?
    var publisher: String?
    var doi: String?
    var volume: Int?
    
    var authors: [Person]?
    private(set) var keywords: [String]?
    
    /// Creates this scientific document
    ///
    /// - parameter uri: Path on file or web
    /// - parameter plainTextContent: Contents of whole file
    /// - parameter title: Title of the PDF
    /// - parameter authors: List of authors for the document (if any)
    /// - parameter keywords: List of keywords for the document (if any)
    init(uri: String, plainTextContent: String?, title: String?, authors: [Person]?, keywords: [String]?, subject: String?) {
        self.authors = authors
        self.keywords = keywords
        self.booktitle = subject
        
        super.init(uri: uri, plainTextContent: plainTextContent, title: title)
        
    }
    
    /// Create document from dime's json.
    override init(fromDime json: JSON) {
        super.init(fromDime: json)
        if let authors = json["authors"].array {
            if authors.count > 0 {
                self.authors = [Person]()
                for author in authors {
                    self.authors!.append(Person(fromDime: author))
                }
            }
        }
    }
    
    /// Update document's fields from crossref's json.
    func updateFields(fromCrossRef json: JSON) {
        if let status = json["status"].string where status == "ok" {
            if let title = json["message"]["title"][0].string {
                self.title = title
            }
            if let subj = json["message"]["container-title"][0].string {
                self.booktitle = subj
            }
            if let auths = json["message"]["author"].array {
                self.authors = auths.flatMap({Person(fromCrossRef: $0)})
            }
            if let doi = json["message"]["DOI"].string {
                self.doi = doi
            }
            if let year = json["message"]["issued"]["date-parts"][0][0].int {
                self.year = year
            }
            if let ps = json["message"]["page"].string, words = ps.words() {
                self.firstPage = Int(words[0])
                if words.count > 1 {
                    self.lastPage = Int(words[1])
                }
            }
            if let publisher = json["message"]["publisher"].string {
                self.publisher = publisher
            }
            if let volume = json["message"]["volume"].string {
                self.volume = Int(volume)
            }
        }
    }
    
    /// Get dict for scientific document is overridden to allow for just-in-time creation of sub-dicts
    override func getDict() -> [String : AnyObject] {
        theDictionary = super.getDict()
        
        // dime-required
        theDictionary["@type"] = "ScientificDocument"
        theDictionary["type"] = "http://www.hiit.fi/ontologies/dime/#ScientificDocument"
        
        if let authors = authors {
            var authArray = [[String: AnyObject]]()
            for auth in authors {
                authArray.append(auth.getDict())
            }
            theDictionary["authors"] = authArray
        }
        if let keywords = keywords {
            theDictionary["keywords"] = keywords
        }
        if let j = booktitle {
            theDictionary["booktitle"] = j
        }
        if let doi = doi {
            theDictionary["doi"] = doi
        }
        if let year = year {
            theDictionary["year"] = year
        }
        if let fp = firstPage {
           theDictionary["firstPage"] = fp
        }
        if let lp = lastPage {
           theDictionary["lastPage"] = lp
        }
        if let publisher = publisher {
            theDictionary["publisher"] = publisher
        }
        if let volume = volume {
            theDictionary["volume"] = volume
        }
        
        return theDictionary
    }
    
}
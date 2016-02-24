//
//  ScientificDocument.swift
//  PeyeDF
//
//  Created by Marco Filetti on 20/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

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
                    self.authors!.append(Person(fromJson: author))
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
                self.authors = [Person]()
                for auth in auths {
                    let authString = auth["given"].stringValue + " " + auth["family"].stringValue
                    if let p = Person(fromString: authString) {
                        self.authors!.append(p)
                    }
                }
            }
            if let doi = json["message"]["DOI"].string {
                self.doi = doi
            }
            if let year = json["message"]["issued"]["date-parts"][0].int {
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
            if let volume = json["message"]["volume"].int {
                self.volume = volume
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
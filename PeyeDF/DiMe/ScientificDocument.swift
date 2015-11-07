//
//  ScientificDocument.swift
//  PeyeDF
//
//  Created by Marco Filetti on 20/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Foundation

class ScientificDocument: DocumentInformationElement {
    
    private(set) var authors: [Person]?
    private(set) var keywords: [String]?
    
    /// Creates this scientific document
    ///
    /// - parameter uri: Path on file or web
    /// - parameter plainTextContent: Contents of whole file
    /// - parameter title: Title of the PDF
    /// - parameter authors: List of authors for the document (if any)
    /// - parameter keywords: List of keywords for the document (if any)
    init(uri: String, plainTextContent: String?, title: String?, authors: [Person]?, keywords: [String]?) {
        self.authors = authors
        self.keywords = keywords
        
        super.init(uri: uri, plainTextContent: plainTextContent, title: title)
        
    }
    
    /// Create document from dime's json.
    override init(fromJson json: JSON) {
        super.init(fromJson: json)
        if let authors = json["authors"].array {
            if authors.count > 0 {
                self.authors = [Person]()
                for author in authors {
                    self.authors!.append(Person(fromJson: author))
                }
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
        
        return theDictionary
    }
    
}
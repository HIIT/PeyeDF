//
//  InformationElement.swift
//  PeyeDF
//
//  Created by Marco Filetti on 24/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

class DocumentInformationElement: DiMeBase {
    
    let uri: String
    let title: String?
    let plainTextContent: String?
    let id: String
    
    /// Creates this information element. The id is set to the hash of the plaintext, or hash of uri if no text was found.
    ///
    /// - parameter uri: Path on file or web
    /// - parameter plainTextContent: Contents of whole file
    /// - parameter title: Title of the PDF
    init(uri: String, plainTextContent: String?, title: String?) {
        self.uri = uri
        self.plainTextContent = plainTextContent
        self.title = title
        
        if let ptc = plainTextContent {
            self.id = "PeyeDF_\(ptc.sha1())"
        } else {
            self.id = "PeyeDF_\(uri.sha1())"
        }
        
        super.init()
        
    }
    
    /// Returns a dime-compatible dictionary for this information element
    /// Sublasses must call this before editing their dictionary.
    override func getDict() -> [String : AnyObject] {
        theDictionary["uri"] = "file://" + uri
        theDictionary[PeyeConstants.iId] = self.id
        if let ptc = plainTextContent {
            theDictionary["plainTextContent"] = ptc
        }
        if let title = title {
            theDictionary["title"] = title
        }
        theDictionary["mimeType"] = "application/pdf"  // forcing pdf for mime type
        
        // dime-required
        theDictionary["@type"] = "Document"
        theDictionary["type"] = "http://www.hiit.fi/ontologies/dime/#Document"
        
        return theDictionary
    }
    
    /// Creates information element from json
    init(fromJson json: JSON) {
        self.uri = json["uri"].stringValue.skipPrefix(7) // skip file:// prefix when importing
        self.title = json["title"].string
        self.plainTextContent = json["plainTextContent"].string
        self.id = json[PeyeConstants.iId].stringValue
    }
    
    /// Returns id using own dictionary
    func getId() -> String {
        return theDictionary[PeyeConstants.iId]! as! String
    }
}

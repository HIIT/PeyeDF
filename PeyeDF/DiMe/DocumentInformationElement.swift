//
//  InformationElement.swift
//  PeyeDF
//
//  Created by Marco Filetti on 24/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

class DocumentInformationElement: DiMeBase {
    
    /// Creates this information element. The id is set to the hash of the plaintext, or hash of uri if no text was found.
    ///
    /// - parameter uri: Path on file or web
    /// - parameter plainTextContent: Contents of whole file
    /// - parameter title: Title of the PDF
    init(uri: String, plainTextContent: String?, title: String?) {
        super.init()
        
        theDictionary["uri"] = uri
        if let ptc = plainTextContent {
            theDictionary["plainTextContent"] = ptc
            theDictionary["id"] = ptc.sha1()
        } else {
            theDictionary["id"] = uri.sha1()
        }
        if let title = title {
            theDictionary["title"] = title
        }
        theDictionary["mimeType"] = "application/pdf"  // forcing pdf for mime type
        
        // dime-required
        theDictionary["@type"] = "Document"
        theDictionary["type"] = "http://www.hiit.fi/ontologies/dime/#Document"
    }
    
    /// Returns id using own dictionary
    func getId() -> String {
        return theDictionary["id"]! as! String
    }
}

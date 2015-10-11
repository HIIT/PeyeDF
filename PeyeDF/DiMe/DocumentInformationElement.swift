//
//  InformationElement.swift
//  PeyeDF
//
//  Created by Marco Filetti on 24/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

class DocumentInformationElement: DiMeBase {
    
    let id: String
    
    /** Creates this information element
        
        - parameter uri: Path on file or web
        - parameter id: Id (hash of plaintext or url)
        - parameter plainTextContent: Contents of whole file
        - parameter title: Title of the PDF
    */
    init(uri: String, id: String, plainTextContent: String?, title: String?) {
        self.id = id
        super.init()
        
        theDictionary["uri"] = uri
        theDictionary["id"] = id
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
    }
    
}

//
//  InformationElement.swift
//  PeyeDF
//
//  Created by Marco Filetti on 24/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

struct DocumentInformationElement: JSONable, Equatable {
    /// Path on file or web
    var uri: String
    
    /// Id (hash of plaintext or url)
    var id: String
    
    /// Contents of whole file
    var plainTextContent: String
    
    /// Title of the PDF
    var title: String
    
    /// Mime type (forcing pdf)
    let mimeType: String = "application/pdf"
    
    func JSONize() -> JSONableItem {
        var retDict = [NSString: JSONableItem]()
        retDict["@type"] = JSONableItem.String("Document")
        retDict["id"] = JSONableItem.String(id)
        retDict["plainTextContent"] = JSONableItem.String(plainTextContent)
        retDict["uri"] = JSONableItem.String(uri)
        retDict["mimeType"] = JSONableItem.String(mimeType)
        retDict["title"] = JSONableItem.String(title)
        return .Dictionary(retDict)
    }
}

/// Assumes two elements are the same if id is the same
func == (lhs: DocumentInformationElement, rhs: DocumentInformationElement) -> Bool {
    return (lhs.id == rhs.id)
}
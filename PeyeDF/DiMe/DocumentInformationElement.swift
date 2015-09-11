//
//  InformationElement.swift
//  PeyeDF
//
//  Created by Marco Filetti on 24/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

class DocumentInformationElement: NSObject, DiMeAble, Dictionariable {
    
    var json: JSON
    var id: String
    
    /** Creates this information element
        
        :param: uri Path on file or web
        :param: id Id (hash of plaintext or url)
        :param: plainTextContent Contents of whole file
        :param: title Title of the PDF
    */
    init(uri: String, id: String, plainTextContent: String, title: String) {
        var retDict = [String: AnyObject]()
        self.json = JSON(retDict)
        self.id = id
        super.init()
        setDiMeDict()
        
        json["uri"] = JSON(uri)
        json["id"] = JSON(id)
        json["plainTextContent"] = JSON(plainTextContent)
        json["title"] = JSON(title)
        json["mimeType"] = "application/pdf"  // forcing pdf for mime type
    }
    
    func setDiMeDict() {
        json["@type"] = JSON("Document")
        json["type"] = JSON("http://www.hiit.fi/ontologies/dime/#Document")
    }
    
    func getDict() -> [String : AnyObject] {
        return json.dictionaryObject!
    }
}
//
//  ResourcedEvent.swift
//  PeyeDF
//
//  Created by Marco Filetti on 25/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

/// Used to send the first-time file opening event
class DesktopEvent: Event, DiMeAble, Dictionariable {
    
    init(infoElem: DocumentInformationElement) {
        super.init()
        self.json["targettedResource"] = JSON(infoElem.getDict())
        setDiMeDict()
    }
    
    func setDiMeDict() {
        self.json["@type"] = JSON("DesktopEvent")
        self.json["type"] = JSON("http://www.hiit.fi/ontologies/dime/#DesktopEvent")
    }
    
    func getDict() -> [String : AnyObject] {
        return json.dictionaryObject!
    }
    
}
//
//  ResourcedEvent.swift
//  PeyeDF
//
//  Created by Marco Filetti on 25/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

/// Used to send the first-time file opening event
class DesktopEvent: Event {
    
    init(sciDoc: ScientificDocument) {
        super.init()
        theDictionary["targettedResource"] = sciDoc.getDict()
        
        // dime-required
        theDictionary["@type"] = "DesktopEvent"
        theDictionary["type"] = "http://www.hiit.fi/ontologies/dime/#DesktopEvent"
    }
    
}
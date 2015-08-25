//
//  ResourcedEvent.swift
//  PeyeDF
//
//  Created by Marco Filetti on 25/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

/// Used to send the first-time file opening event
struct DesktopEvent: JSONable {
    
    var infoElem: DocumentInformationElement
    
    func JSONize() -> JSONableItem {
        var retDict = [NSString: JSONableItem]()
        retDict["targettedResource"] = infoElem.JSONize()
        retDict["@type"] = JSONableItem.String("DesktopEvent")
        
        retDict["type"] = JSONableItem.String("http://www.hiit.fi/ontologies/dime/#DesktopEvent")
        retDict["actor"] = JSONableItem.String("PeyeDF")
        retDict["origin"] = JSONableItem.String("xcode")
        
        return .Dictionary(retDict)
    }
}
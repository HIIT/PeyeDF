//
//  Event.swift
//  PeyeDF
//
//  Created by Marco Filetti on 27/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

/// Note: this class is for subclassing and should not be used directly.
/// subclasses must implement the DiMeAble protocol.
class Event: NSObject {
    
    var json: JSON
    
    /// Must be called by subclasses
    override init() {
        let retDict = [String: AnyObject]()
        
        self.json = JSON(retDict)
        // Make creation date
        json["start"] = JSON(PeyeConstants.diMeDateFormatter.stringFromDate(NSDate()))
        json["actor"] = JSON("PeyeDF")
        json["origin"] = JSON("ORIGIN")
        
        super.init()
    }
    
    /// Set an end date for this item (otherwise, won't be submitted)
    func setEnd(endDate: NSDate) {
        json["end"] = JSON(PeyeConstants.diMeDateFormatter.stringFromDate(endDate))
    }
}
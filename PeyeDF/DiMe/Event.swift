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
class Event: DiMeBase {
    
    /// Must be called by subclasses
    override init() {
        super.init()
        
        // Make creation date
        theDictionary["start"] = PeyeConstants.diMeDateFormatter.stringFromDate(NSDate())
        theDictionary["actor"] = "PeyeDF"
        if let hostname = NSHost.currentHost().name {
            theDictionary["origin"] = hostname
        }
        
        // set dime-required fields (these are defaults that can be overwritten by subclasses)
        theDictionary["@type"] = "Event"
        theDictionary["type"] = "http://www.hiit.fi/ontologies/dime/#Event"
    }
    
    /// Set an end date for this item (otherwise, won't be submitted)
    func setEnd(endDate: NSDate) {
        theDictionary["end"] = PeyeConstants.diMeDateFormatter.stringFromDate(endDate)
    }
}
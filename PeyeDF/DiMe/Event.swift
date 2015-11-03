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
    let startDate: NSDate
    
    /// Must be called by subclasses that create an event starting now
    override init() {
        startDate = NSDate()
        super.init()
        
        // Make creation date
        theDictionary["start"] = PeyeConstants.diMeDateFormatter.stringFromDate(startDate)
        theDictionary["actor"] = "PeyeDF"
        if let hostname = NSHost.currentHost().name {
            theDictionary["origin"] = hostname
        }
        
        // set dime-required fields (these are defaults that can be overwritten by subclasses)
        theDictionary["@type"] = "Event"
        theDictionary["type"] = "http://www.hiit.fi/ontologies/dime/#Event"
    }
    
    /// Must be called by subclasses that create an event with a specific starting date
    init(withStartDate date: NSDate) {
        startDate = date
        super.init()
        
        // Make creation date
        theDictionary["start"] = PeyeConstants.diMeDateFormatter.stringFromDate(startDate)
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
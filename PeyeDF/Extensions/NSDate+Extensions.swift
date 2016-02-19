//
//  NSDate+Extensions.swift
//  PeyeDF
//
//  Created by Marco Filetti on 19/02/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation

extension NSDate {
    
    /// Number of ms since 1/1/1970. Read-only computed property.
    var unixTime: Int { get {
        return Int(round(self.timeIntervalSince1970 * 1000))
        }
    }
    
    
    /// Returns the current time in a short format, e.g. 16:30.45
    /// Use this to pass dates to DiMe
    static func shortTime() -> String {
        let currentDate = NSDate()
        let dsf = NSDateFormatter()
        dsf.dateFormat = "HH:mm.ss"
        return dsf.stringFromDate(currentDate)
    }

}
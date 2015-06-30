//
//  Utils.swift
//  PeyeDF
//
//  Created by Marco Filetti on 30/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//
// Contains various functions and utilities not otherwise classified

import Foundation

/// Returns the current time in a short format, e.g. 16:30.45
func GetCurrentTimeShort() -> String {
    let date = NSDate()
    let dsf = NSDateFormatter()
    dsf.dateFormat = "HH:mm.ss"
    return dsf.stringFromDate(date)
}
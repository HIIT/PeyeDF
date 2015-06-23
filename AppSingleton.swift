//
//  AppSingleton.swift
//  PeyeDF
//
//  Created by Marco Filetti on 23/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa

/// Used to share states across the whole application. Contains:
///
/// - debugState: used to pass around debugging information
class AppSingleton {
    static let debugState = DebugState()
}

/// Stores debug-related information (for example instance of the main debug window)
class DebugState:NSObject, NSTableViewDataSource {
    func numberOfRowsInTableView(aTableView: NSTableView) -> Int {
        return 3
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        //return tableColumn!.identifier + ", " + String(row)
        println(tableColumn!.identifier)
        return "vaf"
    }
    
}
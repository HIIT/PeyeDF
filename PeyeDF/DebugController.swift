//
//  ToolController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 10/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa
import Quartz

/// Controller for the stuff within the Debug Window
class DebugController: NSViewController {
    
    @IBOutlet weak var debugTable: NSTableView!
    
    override func viewDidLoad() {
        debugTable.setDataSource(AppSingleton.debugData)
    }
    
}
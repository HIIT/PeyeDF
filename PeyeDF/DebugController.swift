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
    override func viewDidLoad() {
        debugTable.setDataSource(AppSingleton.debugData)
        AppSingleton.debugData.tabView = debugTable
    }
    
    override func viewDidAppear() {
        //debugTable.reloadData()
    }


    @IBOutlet weak var zoomLab: NSTextField!
    @IBOutlet weak var zoomLab2: NSTextField!
    @IBOutlet weak var trackALabel: NSTextField!
    @IBOutlet weak var boundsLabel: NSTextField!
    @IBOutlet weak var winLabel: NSTextField!
    @IBOutlet weak var debugTable: NSTableView!
    
    
}
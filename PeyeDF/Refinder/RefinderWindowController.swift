//
//  RefinderWindowController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 20/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Cocoa

class RefinderWindowController: NSWindowController {
    
    weak var allHistoryController: AllHistoryController?
    
    override func windowDidLoad() {
        let svc = self.contentViewController as! NSSplitViewController
        allHistoryController = (svc.childViewControllers[0] as! AllHistoryController)
        allHistoryController?.reloadData()
    }
    
    @IBAction func reloadData(sender: AnyObject) {
        allHistoryController?.reloadData()
    }

}

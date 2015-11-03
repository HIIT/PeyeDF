//
//  RefinderWindowController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 20/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Cocoa

class RefinderWindowController: NSWindowController {

    @IBAction func reloadData(sender: AnyObject) {
        let svc = self.contentViewController as! NSSplitViewController
        let vc = svc.childViewControllers[0] as! AllHistoryController
        vc.reloadData()
    }

}

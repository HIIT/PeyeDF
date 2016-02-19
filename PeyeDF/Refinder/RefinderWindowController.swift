//
//  RefinderWindowController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 20/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Cocoa

class RefinderWindowController: NSWindowController, NSWindowDelegate {
    
    /// Whether we want to reload data on next window is main event
    var reloadDataNext = true
    
    weak var allHistoryController: AllHistoryController?
    weak var historyDetailController: HistoryDetailController?
    
    override func windowDidLoad() {
        self.window!.delegate = self
        let svc = self.contentViewController as! NSSplitViewController
        allHistoryController = (svc.childViewControllers[0] as! AllHistoryController)
        historyDetailController = (svc.childViewControllers[1] as! HistoryDetailController)
        allHistoryController?.delegate = historyDetailController
    }
    
    func windowDidBecomeMain(notification: NSNotification) {
        if reloadDataNext {
            reloadData(self)
            reloadDataNext = false
        }
    }
    
    @IBAction func reloadData(sender: AnyObject) {
        if HistoryManager.sharedManager.dimeAvailable {
            // retrieve data
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                self.allHistoryController?.reloadData()
            }
        } else {
            AppSingleton.alertUser("DiMe not available")
        }
    }

}

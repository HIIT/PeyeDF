//
//  RefinderWindowController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 20/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Cocoa

class RefinderWindowController: NSWindowController, NSWindowDelegate {
    
    /// Window for wait controller
    var waitWindow: NSWindow!
    
    /// Wait wiew controller (should be attached to waitWindow)
    var waitVC: WaitViewController!
    
    /// Whether we want to reload data on next window is main event
    var reloadDataNext = true
    
    weak var allHistoryController: AllHistoryController?
    weak var historyDetailController: HistoryDetailController?
    
    override func windowDidLoad() {
        // prepare wait window and view controller
        waitWindow = NSWindow()
        waitVC = AppSingleton.mainStoryboard.instantiateControllerWithIdentifier("WaitVC") as! WaitViewController
        waitWindow.contentViewController = waitVC
        waitVC.someText = "Retrieving data from DiMe..."
        
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
    
    /// Hides the wait view controller (some loading is complete)
    func loadingComplete() {
        dispatch_async(dispatch_get_main_queue()) {
            self.window!.endSheet(self.waitWindow)
        }
    }
    
    /// Show the loading sheet (some loading started)
    func loadingStarted() {
        self.window!.beginSheet(waitWindow, completionHandler: nil)
    }
    
    @IBAction func reloadData(sender: AnyObject) {
        if HistoryManager.sharedManager.dimeAvailable {
            loadingStarted()
            // retrieve data
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                self.allHistoryController?.reloadData()
            }
        } else {
            AppSingleton.alertUser("DiMe not available")
        }
    }

}

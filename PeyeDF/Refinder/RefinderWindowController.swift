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
        allHistoryController?.reloadCompletionCallback = reloadingComplete
        allHistoryController?.delegate = historyDetailController
    }
    
    func windowDidBecomeMain(notification: NSNotification) {
        reloadData(self)
    }
    
    /// Hides the wait view controller (once reloading is complete)
    func reloadingComplete() {
        dispatch_async(dispatch_get_main_queue()) {
            self.window!.endSheet(self.waitWindow)
        }
    }
    
    @IBAction func reloadData(sender: AnyObject) {
        self.window!.beginSheet(waitWindow, completionHandler: nil)
        // retrieve data
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
            self.allHistoryController?.reloadData()
        }
    }

}

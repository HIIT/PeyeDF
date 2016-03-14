//
// Copyright (c) 2015 Aalto University
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

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
    
    // MARK: - Re-Opening
    
    /// Opens a document corresponding to the current document with the same annotations
    /// as those which are being shown.
    @IBAction func reOpenDocument(sender: AnyObject?) {
        historyDetailController?.reOpenDocument(self)
    }
    
    @objc override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
        if menuItem.title == "Re-Open" && historyDetailController != nil {
            return historyDetailController!.validateMenuItem(menuItem)
        } else if menuItem.title == "Reload Data" {
            return true
        } else {
            // any other tag was not considered we disable it by default
            // we can print to check who else is calling this function using
            // print(menuItem.action)
            return false
        }
    }

}

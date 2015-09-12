//
//  AppDelegate.swift
//  PeyeDF
//
//  Created by Marco Filetti on 10/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Cocoa
import Quartz

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    /// Creates default preferences
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        var defaultPrefs = [String: AnyObject]()
        defaultPrefs[PeyeConstants.prefMonitorDPI] = 110  // defaulting monitor DPI to 110 as this is developing PC's DPI
        defaultPrefs[PeyeConstants.prefAnnotationLineThickness] = 1.0
        defaultPrefs[PeyeConstants.prefServerURL] = "http://localhost:8080/api"
        defaultPrefs[PeyeConstants.prefServerUserName] = "Test1"
        defaultPrefs[PeyeConstants.prefServerPassword] = "123456"
        defaultPrefs[PeyeConstants.prefSendEventOnFocusSwitch] = 0
        NSUserDefaults.standardUserDefaults().registerDefaults(defaultPrefs)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    /// Find menu item is linked to this global function
    @IBAction func manualSearch(sender: AnyObject) {
        if let keyWin = NSApplication.sharedApplication().keyWindow {
            if let docWinController = keyWin.windowController() as? DocumentWindowController {
                docWinController.focusOnSearch()
            }
        }
    }

    @IBAction func allDocMetadata(sender: AnyObject) {
        let doci = NSDocumentController.sharedDocumentController().documents
        var outString = ""
        var inum = 1
        for doc: PeyeDocument in doci as! [PeyeDocument] {
            outString += "-- Document \(inum) --\n" +
            "Filename: \(doc.filename)\n" +
            "Title: \(doc.title)\nAuthor(s):\(doc.authors)\n\n"
            ++inum
        }
        if let mainWin = NSApplication.sharedApplication().mainWindow {
            let myAl = NSAlert()
            myAl.messageText = outString
            myAl.beginSheetModalForWindow(mainWin, completionHandler: nil)
        }
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldOpenUntitledFile(sender: NSApplication) -> Bool {
        return false
    }

}


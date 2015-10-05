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

    /// Outlet for connect to dime menu item
    @IBOutlet weak var connectDime: NSMenuItem!
    
    /// Connect midas menu item
    @IBOutlet weak var connectMidas: NSMenuItem!
    
    /// Creates default preferences
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        var defaultPrefs = [String: AnyObject]()
        defaultPrefs[PeyeConstants.prefDominantEye] = Eye.right.rawValue
        defaultPrefs[PeyeConstants.prefMonitorDPI] = 110  // defaulting monitor DPI to 110 as this is developing PC's DPI
        defaultPrefs[PeyeConstants.prefAnnotationLineThickness] = 1.0
        defaultPrefs[PeyeConstants.prefServerURL] = "http://localhost:8080/api"
        defaultPrefs[PeyeConstants.prefServerUserName] = "Test1"
        defaultPrefs[PeyeConstants.prefServerPassword] = "123456"
        defaultPrefs[PeyeConstants.prefUseMidas] = 0
        defaultPrefs[PeyeConstants.prefSendEventOnFocusSwitch] = 0
        NSUserDefaults.standardUserDefaults().registerDefaults(defaultPrefs)
        NSUserDefaults.standardUserDefaults().synchronize()
        
        // Attempt dime connection (required even if we don't use dime, because this sets up historymanager shared object)
        HistoryManager.sharedManager.dimeConnect()  // will automatically detect if dime is down
        
        // If we want to use midas, start the manager
        let useMidas = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefUseMidas) as! Bool
        if useMidas {
            MidasManager.sharedInstance.start()   
        }
        
        // Monitor dime down/up
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "dimeConnectionChanged:", name: PeyeConstants.diMeConnectionNotification, object: HistoryManager.sharedManager)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "midasConnectionChanged:", name: PeyeConstants.midasConnectionNotification, object: MidasManager.sharedInstance)
    }
    
    /// Callback for click on connect to dime
    @IBAction func connectDime(sender: NSMenuItem) {
        HistoryManager.sharedManager.dimeConnect()
    }
    
    /// Callback for connect to midas menu action
    @IBAction func connectMidas(sender: NSMenuItem) {
        MidasManager.sharedInstance.start()
    }
    
    /// Find menu item is linked to this global function
    @IBAction func manualSearch(sender: AnyObject) {
        if let keyWin = NSApplication.sharedApplication().keyWindow {
            if let docWinController = keyWin.windowController as? DocumentWindowController {
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
        MidasManager.sharedInstance.stop()
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PeyeConstants.diMeConnectionNotification, object: HistoryManager.sharedManager)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PeyeConstants.midasConnectionNotification, object: MidasManager.sharedInstance)
    }
    
    func applicationShouldOpenUntitledFile(sender: NSApplication) -> Bool {
        return false
    }
    
    /// MARK: - Notification callbacks
    
    @objc func dimeConnectionChanged(notification: NSNotification) {
        let userInfo = notification.userInfo as! [String: Bool]
        let dimeAvailable = userInfo["available"]!
        
        if dimeAvailable {
            connectDime.state = NSOnState
            connectDime.enabled = false
            connectDime.title = "Connected to dime"
        } else {
            connectDime.state = NSOffState
            connectDime.enabled = true
            connectDime.title = "Connect to dime"
        }
    }
    
    @objc func midasConnectionChanged(notification: NSNotification) {
        let userInfo = notification.userInfo as! [String: Bool]
        let midasAvailable = userInfo["available"]!
        
        if midasAvailable {
            connectMidas.state = NSOnState
            connectMidas.enabled = false
            connectMidas.title = "Connected to Midas"
        } else {
            connectMidas.state = NSOffState
            connectMidas.enabled = true
            connectMidas.title = "Connect to Midas"
        }
    }
}


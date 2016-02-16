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
    
    /// Refinder window
    var refinderWindow: NSWindowController?
    
    /// Creates default preferences
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        var defaultPrefs = [String: AnyObject]()
        defaultPrefs[PeyeConstants.prefDominantEye] = Eye.right.rawValue
        defaultPrefs[PeyeConstants.prefMonitorDPI] = 110  // defaulting monitor DPI to 110 as this is developing PC's DPI
        defaultPrefs[PeyeConstants.prefAnnotationLineThickness] = 1.0
        defaultPrefs[PeyeConstants.prefDiMeServerURL] = "http://localhost:8080/api"
        defaultPrefs[PeyeConstants.prefDiMeServerUserName] = "Test1"
        defaultPrefs[PeyeConstants.prefDiMeServerPassword] = "123456"
        defaultPrefs[PeyeConstants.prefUseMidas] = 0
        defaultPrefs[PeyeConstants.prefRefinderDrawGazedUpon] = 0
        defaultPrefs[PeyeConstants.prefDrawDebugCircle] = 0
        defaultPrefs[PeyeConstants.prefSendEventOnFocusSwitch] = 0
        NSUserDefaults.standardUserDefaults().registerDefaults(defaultPrefs)
        NSUserDefaults.standardUserDefaults().synchronize()
        
        // Attempt dime connection (required even if we don't use dime, because this sets up historymanager shared object)
        HistoryManager.sharedManager.dimeConnect()  // will automatically detect if dime is down
        
        // If we want to use midas, start the manager
        let useMidas = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefUseMidas) as! Bool
        if useMidas {
            MidasManager.sharedInstance.start()
            MidasManager.sharedInstance.setFixationDelegate(HistoryManager.sharedManager)
        }
        
        // Dime/Midas down/up observers
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "dimeConnectionChanged:", name: PeyeConstants.diMeConnectionNotification, object: HistoryManager.sharedManager)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "midasConnectionChanged:", name: PeyeConstants.midasConnectionNotification, object: MidasManager.sharedInstance)
    }
    
    /// Show refinder window (creating it, if needed)
    @IBAction func showRefinderWindor(sender: AnyObject) {
        if refinderWindow == nil {
            refinderWindow = (AppSingleton.refinderStoryboard.instantiateControllerWithIdentifier("RefinderWindowController") as! NSWindowController)
        }
        refinderWindow!.showWindow(self)
    }
    
    /// Callback for click on connect to dime
    @IBAction func connectDime(sender: NSMenuItem) {
        HistoryManager.sharedManager.dimeConnect()
    }
    
    /// Callback for connect to midas menu action
    @IBAction func connectMidas(sender: NSMenuItem) {
        if connectMidas.state == NSOffState {
            MidasManager.sharedInstance.start()
            MidasManager.sharedInstance.setFixationDelegate(HistoryManager.sharedManager)
        } else {
            MidasManager.sharedInstance.stop()
            MidasManager.sharedInstance.unsetFixationDelegate(HistoryManager.sharedManager)
        }
    }
    
    /// Find menu item is linked to this global function
    @IBAction func manualSearch(sender: AnyObject) {
        if let keyWin = NSApplication.sharedApplication().keyWindow {
            if let docWinController = keyWin.windowController as? DocumentWindowController {
                docWinController.focusOnSearch()
            }
        }
    }
    
    /// Shows logs menu
    @IBAction func showLogsPath(sender: AnyObject) {
        if let logsPath = AppSingleton.logsURL.path {
            NSPasteboard.generalPasteboard().declareTypes([NSStringPboardType], owner: self)
            NSPasteboard.generalPasteboard().setString(logsPath, forType: NSStringPboardType)
            AppSingleton.alertUser("Logs file path copied to clipboard.", infoText: logsPath)
        } else {
            AppSingleton.alertUser("Nothing logged so far.")
        }
    }

    @IBAction func allDocMetadata(sender: AnyObject) {
        let doci = NSDocumentController.sharedDocumentController().documents
        var outString = ""
        var inum = 1
        for doc: PeyeDocument in doci as! [PeyeDocument] {
            outString += "-- Document \(inum) --\n" +
            "Filename: \(doc.pdfDoc!.documentURL().lastPathComponent!)\n" +
            "Title: \(doc.pdfDoc!.getTitle())\nAuthor(s):\(doc.pdfDoc!.getAuthor())\n\n"
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
        MidasManager.sharedInstance.unsetFixationDelegate(HistoryManager.sharedManager)
        MidasManager.sharedInstance.stop()
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PeyeConstants.diMeConnectionNotification, object: HistoryManager.sharedManager)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PeyeConstants.midasConnectionNotification, object: MidasManager.sharedInstance)
    }
    
    func applicationShouldOpenUntitledFile(sender: NSApplication) -> Bool {
        return false
    }
    
    // MARK: - Notification callbacks
    
    @objc func dimeConnectionChanged(notification: NSNotification) {
        let userInfo = notification.userInfo as! [String: Bool]
        let dimeAvailable = userInfo["available"]!
        
        if dimeAvailable {
            connectDime.state = NSOnState
            connectDime.enabled = false
            connectDime.title = "Connected to DiMe"
        } else {
            connectDime.state = NSOffState
            connectDime.enabled = true
            connectDime.title = "Connect to DiMe"
        }
    }
    
    @objc func midasConnectionChanged(notification: NSNotification) {
        let userInfo = notification.userInfo as! [String: Bool]
        let midasAvailable = userInfo["available"]!
        
        if midasAvailable {
            connectMidas.state = NSOnState
            connectMidas.title = "Connected to Midas"
        } else {
            connectMidas.state = NSOffState
            connectMidas.title = "Connect to Midas"
        }
    }
}


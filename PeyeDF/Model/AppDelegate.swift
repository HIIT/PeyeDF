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
import Quartz

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Setup

    /// Outlet for connect to dime menu item
    @IBOutlet weak var connectDime: NSMenuItem!
    
    /// Connect midas menu item
    @IBOutlet weak var connectMidas: NSMenuItem!
    
    /// Refinder window
    var refinderWindow: RefinderWindowController?
    
    /// Sets up custom url handler
    func applicationWillFinishLaunching(notification: NSNotification) {
        var defaultPrefs = [String: AnyObject]()
        defaultPrefs[PeyeConstants.prefDominantEye] = Eye.right.rawValue
        defaultPrefs[PeyeConstants.prefMonitorDPI] = 110  // defaulting monitor DPI to 110 as this is developing PC's DPI
        defaultPrefs[PeyeConstants.prefAnnotationLineThickness] = 1.0
        defaultPrefs[PeyeConstants.prefDiMeServerURL] = "http://localhost:8080/api"
        defaultPrefs[PeyeConstants.prefDiMeServerUserName] = "Test1"
        defaultPrefs[PeyeConstants.prefDiMeServerPassword] = "123456"
        defaultPrefs[PeyeConstants.prefUseMidas] = 0
        defaultPrefs[PeyeConstants.prefEnableAnnotate] = 1
        defaultPrefs[PeyeConstants.prefDownloadMetadata] = 1
        defaultPrefs[PeyeConstants.prefRefinderDrawGazedUpon] = 0
        defaultPrefs[PeyeConstants.prefDrawDebugCircle] = 0
        defaultPrefs[PeyeConstants.prefSendEventOnFocusSwitch] = 0
        NSUserDefaults.standardUserDefaults().registerDefaults(defaultPrefs)
        NSUserDefaults.standardUserDefaults().synchronize()
        
        // Attempt dime connection (required even if we don't use dime, because this sets up historymanager shared object)
        HistoryManager.sharedManager.dimeConnect()  // will automatically detect if dime is down
        
        // Set up handler for custom url types (peyedf://)
        NSAppleEventManager.sharedAppleEventManager().setEventHandler(self, andSelector: "handleURL:", forEventClass: UInt32(kInternetEventClass), andEventID: UInt32(kAEGetURL))
    }
    
    /// Creates default preferences and sets up dime
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
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
    
    // MARK: - Opening
    
    func applicationShouldOpenUntitledFile(sender: NSApplication) -> Bool {
        return false
    }
    
    /// Overridden to allow searching from outside (spotlight). Checks for dime before
    /// proceeding.
    func application(sender: NSApplication, openFiles filenames: [String]) {
        let searchString = NSAppleEventManager.sharedAppleEventManager().currentAppleEvent?.descriptorForKeyword(UInt32(keyAESearchText))?.stringValue
        if HistoryManager.sharedManager.dimeAvailable {
            for filename in filenames {
                let fileUrl = NSURL(fileURLWithPath: filename)
                openDocument(fileUrl, searchString: searchString)
            }
        } else {
            HistoryManager.sharedManager.dimeConnect() {
                _ in
                for filename in filenames {
                    let fileUrl = NSURL(fileURLWithPath: filename)
                    self.openDocument(fileUrl, searchString: searchString)
                }
            }
        }
    }
    
    // MARK: - Convenience
    
    /// Convenience function to open a file using a given local url and optionally 
    /// a search string (to initiate a query) and focus area (to highlight a specific area).
    func openDocument(fileURL: NSURL, searchString: String?, focusArea: FocusArea? = nil) {
        NSDocumentController.sharedDocumentController().openDocumentWithContentsOfURL(fileURL, display: true) {
            document, _, _ in
            if let searchS = searchString, doc = document where
              searchS != "" && doc.windowControllers.count == 1 {
                (doc.windowControllers[0] as! DocumentWindowController).doSearch(searchS, exact: false)
            }
            if let f = focusArea, doc = document as? PeyeDocument {
                doc.focusOn(f)
            }
        }
    }
    
    /// A url sent for opening (using host "reader") is sent here.
    func openComponents(comps: NSURLComponents) {
        let query: String? = comps.parameterDictionary?["search"]
        if let path = comps.path where path != "" {
            openDocument(NSURL(fileURLWithPath: path), searchString: query, focusArea: FocusArea(fromURLComponents: comps))
        }
    }
    
    /// Uses the given url components to open refinder and find the given sessionId.
    func refindComponents(comps: NSURLComponents) {
        showRefinderWindow(nil)
        if let _sesId = comps.path where _sesId != "" && _sesId.skipPrefix(1) != "" {
            let sesId = _sesId.skipPrefix(1)
            if let focusArea = FocusArea(fromURLComponents: comps) {
                refinderWindow?.allHistoryController?.focusOn(focusArea, forSessionId: sesId)
            }
            refinderWindow?.allHistoryController?.selectSessionId(sesId)
        }
    }
    
    // MARK: - Actions
    
    /// Show refinder window (creating it, if needed)
    @IBAction func showRefinderWindow(sender: AnyObject?) {
        if refinderWindow == nil {
            refinderWindow = (AppSingleton.refinderStoryboard.instantiateControllerWithIdentifier("RefinderWindowController") as! RefinderWindowController)
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
    
    // MARK: - Closing
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
        MidasManager.sharedInstance.unsetFixationDelegate(HistoryManager.sharedManager)
        MidasManager.sharedInstance.stop()
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PeyeConstants.diMeConnectionNotification, object: HistoryManager.sharedManager)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PeyeConstants.midasConnectionNotification, object: MidasManager.sharedInstance)
    }
    
    // MARK: - Callbacks
    
    /// Handles PeyeDF's url type (with protocol peyedf://)
    @objc func handleURL(event: NSAppleEventDescriptor) {
        if let pDesc = event.paramDescriptorForKeyword(UInt32(keyDirectObject)), stringVal = pDesc.stringValue {
            if let comps = NSURLComponents(string: stringVal), host = comps.host {
                switch host {
                case "reader":
                    comps.onDiMeAvail(openComponents, mustConnect: false)
                case "refinder":
                    comps.onDiMeAvail(refindComponents, mustConnect: true)
                default:
                    AppSingleton.alertUser("\(host) not recognized.", infoText: "Allowed \"hosts\" are 'reader' and 'refinder'.")
                }
            } else {
                AppSingleton.log.error("Failed to convert this to NSURLComponents: \(stringVal)")
            }
        } else {
            AppSingleton.log.error("Failed to retrieve url from event: \(event)")
        }
    }
    
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


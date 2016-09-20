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
import Sparkle
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
    
    /// When the application launched
    let launchDate = Date()
    
    /// PeyeDF closes itself to prevent potential leaks and allow opened PDFs to be deleted (after a given amount of time passed)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return Date().timeIntervalSince(launchDate) > PeyeConstants.closeAfterLaunch && !MidasManager.sharedInstance.midasAvailable && Multipeer.session.connectedPeers.count < 1
    }
    
    /// Sets up custom url handler
    func applicationWillFinishLaunching(_ notification: Notification) {
        var defaultPrefs = [String : Any]()
        defaultPrefs[PeyeConstants.prefDominantEye] = Eye.right.rawValue
        defaultPrefs[PeyeConstants.prefMonitorDPI] = 110  // defaulting monitor DPI to 110 as this is developing PC's DPI
        defaultPrefs[PeyeConstants.prefAnnotationLineThickness] = 1.0
        defaultPrefs[PeyeConstants.prefDiMeServerURL] = "http://localhost:8080/api"
        defaultPrefs[PeyeConstants.prefDiMeServerUserName] = "Test1"
        defaultPrefs[PeyeConstants.prefDiMeServerPassword] = "123456"
        defaultPrefs[PeyeConstants.prefUseMidas] = 0
        defaultPrefs[PeyeConstants.prefAskToSaveOnClose] = 0
        defaultPrefs[PeyeConstants.prefEnableAnnotate] = 0
        defaultPrefs[PeyeConstants.prefDownloadMetadata] = 1
        defaultPrefs[PeyeConstants.prefCheckForUpdatesOnStartup] = 1
        defaultPrefs[PeyeConstants.prefRefinderDrawGazedUpon] = 0
        defaultPrefs[PeyeConstants.prefDrawDebugCircle] = 0
        defaultPrefs[PeyeConstants.prefSendEventOnFocusSwitch] = 0
        defaultPrefs[TagConstants.defaultsSavedTags] = []
        UserDefaults.standard.register(defaults: defaultPrefs)
        UserDefaults.standard.synchronize()
        
        // Attempt dime connection (required even if we don't use dime, because this sets up historymanager shared object)
        DiMeSession.dimeConnect()  // will automatically detect if dime is down
        
        // Set up handler for custom url types (peyedf://)
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURL(_:)), forEventClass: UInt32(kInternetEventClass), andEventID: UInt32(kAEGetURL))
    }
    
    /// Creates default preferences and sets up dime
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Auto-update check
        if UserDefaults.standard.value(forKey: PeyeConstants.prefCheckForUpdatesOnStartup) as! Bool {
            Sparkle.SUUpdater.shared().checkForUpdatesInBackground()
        }
        
        // If we want to use midas, start the manager
        let useMidas = UserDefaults.standard.value(forKey: PeyeConstants.prefUseMidas) as! Bool
        if useMidas {
            MidasManager.sharedInstance.start()
            MidasManager.sharedInstance.setFixationDelegate(HistoryManager.sharedManager)
        }
        
        // Dime/Midas down/up observers
        NotificationCenter.default.addObserver(self, selector: #selector(dimeConnectionChanged(_:)), name: PeyeConstants.diMeConnectionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(midasConnectionChanged(_:)), name:PeyeConstants.midasConnectionNotification, object: MidasManager.sharedInstance)
        
        // Start multipeer connectivity
        Multipeer.advertiser.start()
    }
    
    // MARK: - Opening
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return false
    }
    
    /// Overridden to allow searching from outside (spotlight). Checks for dime before
    /// proceeding.
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let searchString = NSAppleEventManager.shared().currentAppleEvent?.forKeyword(UInt32(keyAESearchText))?.stringValue
        if DiMeSession.dimeAvailable {
            for filename in filenames {
                let fileUrl = URL(fileURLWithPath: filename)
                openDocument(fileUrl, searchString: searchString)
            }
        } else {
            DiMeSession.dimeConnect() {
                _ in
                for filename in filenames {
                    let fileUrl = URL(fileURLWithPath: filename)
                    self.openDocument(fileUrl, searchString: searchString)
                }
            }
        }
    }
    
    // MARK: - Convenience
    
    /// Convenience function to open a file using a given local url and optionally 
    /// a search string (to initiate a query) and focus area (to highlight a specific area).
    func openDocument(_ fileURL: URL, searchString: String?, focusArea: FocusArea? = nil) {
        DispatchQueue.main.async {
            NSDocumentController.shared().openDocument(withContentsOf: fileURL, display: true) {
                document, _, _ in
                if let searchS = searchString, let doc = document ,
                  searchS != "" && doc.windowControllers.count == 1 {
                    (doc.windowControllers[0] as! DocumentWindowController).doSearch(searchS, exact: false)
                }
                if let f = focusArea, let doc = document as? PeyeDocument {
                    doc.focusOn(f)
                }
            }
        }
    }
    
    /// A url sent for opening (using host "reader") is sent here.
    func openComponents(_ comps: URLComponents) {
        let query: String? = comps.parameterDictionary?["search"]
        if comps.path != "" {
            openDocument(URL(fileURLWithPath: comps.path), searchString: query, focusArea: FocusArea(fromURLComponents: comps))
        }
    }
    
    /// Uses the given url components to open refinder and find the given sessionId.
    func refindComponents(_ comps: URLComponents) {
        showRefinderWindow(nil)
        if comps.path != "" && comps.path.skipPrefix(1) != "" {
            let sesId = comps.path.skipPrefix(1)
            if let focusArea = FocusArea(fromURLComponents: comps) {
                refinderWindow?.allHistoryController?.focusOn(focusArea, forSessionId: sesId)
            }
            refinderWindow?.allHistoryController?.selectSessionId(sesId)
        }
    }
    
    // MARK: - Actions
    
    /// Show refinder window (creating it, if needed)
    @IBAction func showRefinderWindow(_ sender: AnyObject?) {
        if refinderWindow == nil {
            refinderWindow = (AppSingleton.refinderStoryboard.instantiateController(withIdentifier: "RefinderWindowController") as! RefinderWindowController)
        }
        refinderWindow!.showWindow(self)
        Multipeer.advertiser.start()
    }
    
    /// Called when clicking on the show network readers menu
    @IBAction func showPeers(_ sender: AnyObject) {
        Multipeer.peerWindow.showWindow(self)
        Multipeer.browserWindow.makeKeyAndOrderFront(self)
    }
    
    /// Callback for click on connect to dime
    @IBAction func connectDime(_ sender: NSMenuItem) {
        DiMeSession.dimeConnect() {
            success, error in
            
            if !success {
                var infoText: String = "<none>"
                if let error = error {
                    infoText = error.localizedDescription
                }
                AppSingleton.alertUser("Error while communcating with DiMe. Dime has now been disconnected", infoText: "Message from dime:\n\(infoText)")
            }
        }
    }
    
    /// Callback for connect to midas menu action
    @IBAction func connectMidas(_ sender: NSMenuItem) {
        if connectMidas.state == NSOffState {
            MidasManager.sharedInstance.start()
            MidasManager.sharedInstance.setFixationDelegate(HistoryManager.sharedManager)
        } else {
            MidasManager.sharedInstance.stop()
            MidasManager.sharedInstance.unsetFixationDelegate(HistoryManager.sharedManager)
        }
    }
    
    /// Find menu item is linked to this global function
    @IBAction func manualSearch(_ sender: AnyObject) {
        if let keyWin = NSApplication.shared().keyWindow {
            if let docWinController = keyWin.windowController as? DocumentWindowController {
                docWinController.focusOnSearch()
            }
        }
    }
    
    /// Shows logs menu
    @IBAction func showLogsPath(_ sender: AnyObject) {
        if let logsPath = AppSingleton.logsURL?.path {
            NSPasteboard.general().declareTypes([NSStringPboardType], owner: self)
            NSPasteboard.general().setString(logsPath, forType: NSStringPboardType)
            AppSingleton.alertUser("Logs file path copied to clipboard.", infoText: logsPath)
        } else {
            AppSingleton.alertUser("Nothing logged so far.")
        }
    }

    @IBAction func allDocMetadata(_ sender: AnyObject) {
        let doci = NSDocumentController.shared().documents
        var outString = ""
        var inum = 1
        for doc: PeyeDocument in doci as! [PeyeDocument] {
            outString += "-- Document \(inum) --\n" +
            "Filename: \(doc.pdfDoc!.documentURL!.lastPathComponent)\n" +
            "Title: \(doc.pdfDoc!.getTitle())\nAuthor(s):\(doc.pdfDoc!.getAuthor())\n\n"
            inum += 1
        }
        if let mainWin = NSApplication.shared().mainWindow {
            let myAl = NSAlert()
            myAl.messageText = outString
            myAl.beginSheetModal(for: mainWin, completionHandler: nil)
        }
    }
    
    // MARK: - Closing
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        MidasManager.sharedInstance.unsetFixationDelegate(HistoryManager.sharedManager)
        MidasManager.sharedInstance.stop()
        NotificationCenter.default.removeObserver(self, name: PeyeConstants.diMeConnectionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: PeyeConstants.midasConnectionNotification, object: MidasManager.sharedInstance)
    }
    
    // MARK: - Callbacks
    
    /// Calls sparkle, asking to check for new version
    @IBAction func checkForUpdates(_ sender: NSMenuItem) {
        Sparkle.SUUpdater.shared().checkForUpdates(self)
    }

    /// Handles PeyeDF's url type (with protocol peyedf://)
    @objc func handleURL(_ event: NSAppleEventDescriptor) {
        if let pDesc = event.paramDescriptor(forKeyword: UInt32(keyDirectObject)), let stringVal = pDesc.stringValue {
            if let comps = URLComponents(string: stringVal), let host = comps.host {
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
    
    @objc func dimeConnectionChanged(_ notification: Notification) {
        let userInfo = (notification as NSNotification).userInfo as! [String: Bool]
        let dimeAvailable = userInfo["available"]!
        
        if dimeAvailable {
            connectDime.state = NSOnState
            connectDime.isEnabled = false
            connectDime.title = "Connected to DiMe"
        } else {
            connectDime.state = NSOffState
            connectDime.isEnabled = true
            connectDime.title = "Connect to DiMe"
        }
    }
    
    @objc func midasConnectionChanged(_ notification: Notification) {
        let userInfo = (notification as NSNotification).userInfo as! [String: Bool]
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


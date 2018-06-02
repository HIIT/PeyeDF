//
// Copyright (c) 2018 University of Helsinki, Aalto University
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
import os.log

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Setup

    /// Outlet for connect to dime menu item
    @IBOutlet weak var connectDime: NSMenuItem!
    
    /// Connect eye tracker menu item
    @IBOutlet weak var connectEyeTracker: NSMenuItem!
    
    /// Refinder window
    var refinderWindow: RefinderWindowController?
    
    /// When the application launched
    let launchDate = Date()
    
    /// PeyeDF closes itself to prevent potential leaks and allow opened PDFs to be deleted (after a given amount of time passed)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return Date().timeIntervalSince(launchDate) > PeyeConstants.closeAfterLaunch && !(AppSingleton.eyeTracker?.available ?? false) && Multipeer.session.connectedPeers.count < 1
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
        defaultPrefs[PeyeConstants.prefStringBlockList] = [" iban ", "iban:", " visa ", " visa:", "mastercard", "american express"]
        defaultPrefs[PeyeConstants.prefEyeTrackerType] = 0
        defaultPrefs[PeyeConstants.prefAskToSaveOnClose] = 0
        defaultPrefs[PeyeConstants.prefConstrainWindowMaxSize] = 0 
        defaultPrefs[PeyeConstants.prefEnableAnnotate] = 0
        defaultPrefs[PeyeConstants.prefDownloadMetadata] = 1
        defaultPrefs[PeyeConstants.prefLoadPreviousAnnotations] = 1
        defaultPrefs[PeyeConstants.prefCheckForUpdatesOnStartup] = 1
        defaultPrefs[PeyeConstants.prefRefinderDrawGazedUpon] = 0
        defaultPrefs[PeyeConstants.prefDrawDebugCircle] = 0
        defaultPrefs[PeyeConstants.prefSendEventOnFocusSwitch] = 0
        defaultPrefs[TagConstants.defaultsSavedTags] = []
        UserDefaults.standard.register(defaults: defaultPrefs)
        UserDefaults.standard.synchronize()
        
        // Set up handler for custom url types (peyedf://)
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURL(_:)), forEventClass: UInt32(kInternetEventClass), andEventID: UInt32(kAEGetURL))
    }
    
    /// Creates default preferences and sets up dime
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Auto-update check
        #if !QUESTIONS
            if UserDefaults.standard.object(forKey: PeyeConstants.prefCheckForUpdatesOnStartup) as! Bool {
                Sparkle.SUUpdater.shared().checkForUpdatesInBackground()
            }
        #endif
        
        // Dime/Eye tracker down/up observers
        NotificationCenter.default.addObserver(self, selector: #selector(dimeConnectionChanged(_:)), name: PeyeConstants.diMeConnectionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(eyeConnectionChanged(_:)), name:PeyeConstants.eyeConnectionNotification, object: nil)
        
        // Attempt dime connection (required even if we don't use dime, because this sets up historymanager shared object)
        DiMeSession.dimeConnect()  // will automatically detect if dime is down
        
        // If we want to use eye tracker, create it and associate us to it
        let eyeTrackerPref = UserDefaults.standard.object(forKey: PeyeConstants.prefEyeTrackerType) as! Int
        if let eyeTrackerType = EyeDataProviderType(rawValue: eyeTrackerPref) {
            if let eyeTracker = eyeTrackerType.associatedTracker {
                AppSingleton.eyeTracker = eyeTracker
            }
        } else {
            if #available(OSX 10.12, *) {
                os_log("Failed to find a corresponding eye data provider type enum for Int: %d", type: .error, eyeTrackerPref)
            }
        }
        
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
                _, _ in
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
    ///
    /// - Parameters:
    ///   - fileURL: URL of file to open
    ///   - searchString: If not nil, search for this string once document is open
    ///   - focusArea: If not nil, focus on this once doument is open
    ///   - previousSessionId: If not nil, associate this session to the session associated to the newly opened document
    ///   - urlRects: If not empty, highlight these rects on the given page indices
    func openDocument(_ fileURL: URL, searchString: String? = nil, focusArea: FocusArea? = nil, previousSessionId: String? = nil, urlRects: [(rect: NSRect, page: Int)] = []) {
        DispatchQueue.main.async {
            NSDocumentController.shared.openDocument(withContentsOf: fileURL, display: true) {
                document, _, _ in
                guard let doc = document as? PeyeDocument,
                      let vc = doc.windowControllers[0] as? DocumentWindowController else {
                        return
                }
                if let searchS = searchString, searchS != "" && doc.windowControllers.count == 1 {
                    vc.doSearch(searchS, exact: false)
                }
                if let f = focusArea {
                    doc.focusOn(f)
                }
                if let previousSessionId = previousSessionId {
                    vc.pdfReader?.previousSessionId = previousSessionId
                }
                if urlRects.count > 0 {
                    vc.pdfReader?.urlRects = urlRects
                }
            }
        }
    }
    
    /// A url sent for opening (using host "reader") is sent here.
    func openComponents(_ comps: URLComponents) {

        guard comps.path != "", comps.path.skipPrefix(1) != "" else {
            return
        }
        
        let query: String? = comps.parameterDictionary?["search"]
        let previousSessionId: String? = comps.parameterDictionary?["previousSessionId"]
        var focusArea: FocusArea?
        // attempt to generate a focus area if we have a page parameter
        if comps.parameterDictionary?["page"] != nil {
            focusArea = FocusArea(fromURLComponents: comps)
        }
        // start markRects parsing
        var urlRects: [(rect: NSRect, page: Int)] = []
        // attempt to create a series of markRects
        // the format is one or more of (x,y,width,height,pagenumber)
        // between square brackets
        if let urlRectsString = comps.parameterDictionary?["markRects"] {
            if urlRectsString.first == "[" && urlRectsString.last == "]" {
                let comps = urlRectsString.components(separatedBy: ["[","]","(",")"])
                // we should have something like this now:
                // ["", "", "10,20,30,40,4", "", "1,2,3,4,5", "", ""]
                for comp in comps {
                    if comp.count >= 9 {
                        let inner = comp.components(separatedBy: ",")
                        if inner.count == 5 {
                            if let x = Double(inner[0]),
                               let y = Double(inner[1]),
                               let width = Double(inner[2]),
                               let height = Double(inner[3]),
                               let pageIndex = Int(inner[4]) {
                                let rect = NSRect(x: x, y: y, width: width, height: height)
                                urlRects.append((rect: rect, page: pageIndex))
                            }
                        }
                    }
                }
            }
        }
        // end markRects parsing

        DispatchQueue.global(qos: .userInitiated).async {
            
            // first check if we have a valid url, if not try to use it as sessionId, if that still doesn't work try contentHash, then appId
            let possibleURL = URL(fileURLWithPath: comps.path)
            var failed = false
            do {
                if try possibleURL.checkResourceIsReachable() {
                    self.openDocument(possibleURL, searchString: query, focusArea: focusArea, previousSessionId: previousSessionId, urlRects: urlRects)
                } else {
                    failed = true
                }
            } catch {
                failed = true
            }
            if failed {
                let path = comps.path.skipPrefix(1)
                // first try to convert path to sessionId, then contentHash, then appId
                let foundSciDoc: ScientificDocument?
                if let sciDoc = DiMeFetcher.getScientificDocument(for: .sessionId(path)) {
                    foundSciDoc = sciDoc
                } else if let sciDoc = DiMeFetcher.getScientificDocument(for: .contentHash(path)) {
                    foundSciDoc = sciDoc
                } else if let sciDoc = DiMeFetcher.getScientificDocument(for: .appId(path)) {
                    foundSciDoc = sciDoc
                } else {
                    foundSciDoc = nil
                }
                if let sciDoc = foundSciDoc {
                    let url = URL(fileURLWithPath: sciDoc.uri)
                    self.openDocument(url, searchString: query, focusArea: focusArea, previousSessionId: previousSessionId, urlRects: urlRects)
                }
            }

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
            refinderWindow = (AppSingleton.refinderStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "RefinderWindowController")) as! RefinderWindowController)
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
                var dimeText = ""
                if let dimeError = error as? RESTError {
                    switch dimeError {
                    case .dimeError(let msg):
                        dimeText = "\nMessage from DiMe:\n\(msg)"
                    default:
                        dimeText = ""
                    }
                }
                AppSingleton.alertUser("Error while communicating with DiMe. Dime has now been disconnected", infoText: "Error description:\n\(infoText)." + dimeText)
            }
        }
    }
    
    /// Show PeyeDF github page
    @IBAction func showGitHub(_ sender: NSMenuItem) {
        let url = URL(string: "https://github.com/HIIT/PeyeDF")
        NSWorkspace.shared.open(url!)
    }
    
    /// Callback for connect to midas menu action
    @IBAction func connectEyeTracker(_ sender: NSMenuItem) {
        if connectEyeTracker.state == .off {
            AppSingleton.eyeTracker?.start()
            AppSingleton.eyeTracker?.fixationDelegate = HistoryManager.sharedManager
        } else {
            AppSingleton.eyeTracker?.stop()
            AppSingleton.eyeTracker?.fixationDelegate = nil
        }
    }
    
    /// Find menu item is linked to this global function
    @IBAction func manualSearch(_ sender: AnyObject) {
        if let keyWin = NSApplication.shared.keyWindow {
            if let docWinController = keyWin.windowController as? DocumentWindowController {
                docWinController.focusOnSearch()
            }
        }
    }
    
    @IBAction func allDocMetadata(_ sender: AnyObject) {
        let doci = NSDocumentController.shared.documents
        var outString = ""
        var inum = 1
        for doc: PeyeDocument in doci as! [PeyeDocument] {
            outString += "-- Document \(inum) --\n" +
            "Filename: \(doc.pdfDoc!.documentURL!.lastPathComponent)\n" +
            "Title: \(doc.pdfDoc!.getTitle() ?? "N/A")\nAuthor(s):\(doc.pdfDoc!.getAuthor() ?? "N/A")\n\n"
            inum += 1
        }
        if let mainWin = NSApplication.shared.mainWindow {
            let myAl = NSAlert()
            myAl.messageText = outString
            myAl.beginSheetModal(for: mainWin, completionHandler: nil)
        }
    }
    
    // MARK: - Closing
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        AppSingleton.eyeTracker?.fixationDelegate = nil
        AppSingleton.eyeTracker?.stop()
        NotificationCenter.default.removeObserver(self, name: PeyeConstants.diMeConnectionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: PeyeConstants.eyeConnectionNotification, object: nil)
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
            }
        }
    }
    
    @objc func dimeConnectionChanged(_ notification: Notification) {
        let userInfo = (notification as NSNotification).userInfo as! [String: Bool]
        let dimeAvailable = userInfo["available"]!
        DispatchQueue.main.async {
            if dimeAvailable {
                self.connectDime.state = .on
                self.connectDime.isEnabled = false
                self.connectDime.title = "Connected to DiMe"
            } else {
                self.connectDime.state = .off
                self.connectDime.isEnabled = true
                self.connectDime.title = "Connect to DiMe"
            }
        }
    }
    
    @objc func eyeConnectionChanged(_ notification: Notification) {
        let userInfo = (notification as NSNotification).userInfo as! [String: Bool]
        let avail = userInfo["available"]!
        
        if avail {
            connectEyeTracker.state = .on
            connectEyeTracker.title = "Connected to Eye Tracker"
        } else {
            connectEyeTracker.state = .off
            connectEyeTracker.title = "Not connected to Eye Tracker"
        }
    }
}


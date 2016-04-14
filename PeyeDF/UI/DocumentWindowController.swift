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
import Foundation
import Quartz

/// Manages the "Document Window", which comprises two split views, one inside the other
class DocumentWindowController: NSWindowController, NSWindowDelegate, SideCollapseToggleDelegate, SearchPanelCollapseDelegate {
    
    /// The "global" GCD queue in which all timers are created / destroyed (to prevent potential memory leaks, they all run here)
    static let timerQueue = dispatch_queue_create("hiit.PeyeDF.DocumentWindowController.timerQueue", DISPATCH_QUEUE_SERIAL)
    
    /// Regular timer for this window
    var regularTimer: NSTimer?
    
    /// When the user started reading (stoppedReading date - this date = reading time).
    /// Should be set to nil when the user stops reading, or on startup.
    /// Setting this value to a new value automatically increases the totalReadingTime
    /// (takes into consideration minimum reading values constants)
    var lastStartedReading: NSDate? {
        didSet {
            // increase total reading time constant if reading time was below minimum.
            // if reading time was above maximum, increase by maximum
            if let rdate = oldValue {
                let rTime = NSDate().timeIntervalSinceDate(rdate)
                if rTime > PeyeConstants.minReadTime {
                    if rTime < PeyeConstants.maxReadTime {
                        totalReadingTime += rTime
                    } else {
                        totalReadingTime += PeyeConstants.maxReadTime
                    }
                }
            }
        }
    }
    
    /// Total reading time spent on this window.
    var totalReadingTime: NSTimeInterval = 0
    
    /// To make sure only one summary event is sent to dime
    var closeToken: Int = 0
    
    weak var pdfReader: MyPDFReader?
    weak var docSplitController: DocumentSplitController?
    weak var mainSplitController: MainSplitController?
    var debugController: DebugController?
    var debugWindowController: NSWindowController?
    @IBOutlet weak var tbMetadata: NSToolbarItem!
    @IBOutlet weak var tbAnnotate: NSToolbarItem!
    @IBOutlet weak var tbTagButton: NSButton!
    
    var metadataWindowController: MetadataWindowController?
    
    weak var clickDelegate: ClickRecognizerDelegate?
    
    lazy var popover: NSPopover = {
            let pop = NSPopover()
            pop.behavior = NSPopoverBehavior.Transient
            let tvc = AppSingleton.tagsStoryboard.instantiateControllerWithIdentifier("TagViewController")
            pop.contentViewController = tvc as! TagViewController
            return pop
        }()
    
    // MARK: - Tagging
    
    @IBAction func tagShow(sender: AnyObject?) {
        dispatch_async(dispatch_get_main_queue()) {
            let tvc = self.popover.contentViewController as! TagViewController
            if !self.popover.shown {
                // if there is a selection, tag selection, otherwise call window's tag method
                if (self.pdfReader!.currentSelection()?.string().trimmed().isEmpty ?? true) {
                    self.popover.showRelativeToRect(self.tbTagButton.bounds, ofView: self.tbTagButton, preferredEdge: NSRectEdge.MinY)
                    tvc.setStatus(true)
                } else {
                    let edge: NSRectEdge
                    // selection's tag popover is shown on the right edge if selection's rect mid > pdf reader rect mid
                    let sel = self.pdfReader!.currentSelection()
                    var selBounds = sel.boundsForPage(sel.pages()[0] as! PDFPage)
                    selBounds = self.pdfReader!.convertRect(selBounds, fromPage: sel.pages()[0] as! PDFPage)
                    if (selBounds.minX + selBounds.size.width / 2) > self.pdfReader!.bounds.width / 2 {
                        edge = NSRectEdge.MaxX
                    } else {
                        edge = NSRectEdge.MinX
                    }
                    self.popover.showRelativeToRect(selBounds, ofView: self.pdfReader!, preferredEdge: edge)
                    tvc.setStatus(false)
                }
            } else {
                self.popover.performClose(self)
            }
        }
    }
    
    // MARK: - Searching
    
    /// Do a search using a predefined string (when called from outside ui, e.g. from other applications)
    /// - parameter exact: If true, searches for exact phrase (false for all words)
    func doSearch(searchString: String, exact: Bool) {
        dispatch_async(dispatch_get_main_queue()) {
            self.mainSplitController?.openSearchPanel()
            self.mainSplitController?.searchPanelController?.doSearch(searchString, exact: exact)
        }
    }
    
    /// Perform search using default methods.
    @objc func performFindPanelAction(sender: AnyObject) {
        switch UInt(sender.tag()) {
        case NSFindPanelAction.ShowFindPanel.rawValue:
            focusOnSearch()
        case NSFindPanelAction.Next.rawValue:
            mainSplitController?.searchProvider?.selectNextResult(nil)
        case NSFindPanelAction.Previous.rawValue:
            mainSplitController?.searchProvider?.selectPreviousResult(nil)
        case NSFindPanelAction.SetFindString.rawValue:
            if let currentSelection = pdfReader!.currentSelection() {
                mainSplitController?.searchProvider?.doSearch(currentSelection.string(), exact: true)
                mainSplitController?.openSearchPanel()
            }
        default:
            let exception = NSException(name: "Unimplemented search function", reason: "Enum raw value not recognized", userInfo: nil)
            exception.raise()
        }
    }
    
    /// Checks which menu items should be enabled (some logic used for find next and previous menu items).
    @objc override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
        switch UInt(menuItem.tag) {
            
        // we always allow find
        case NSFindPanelAction.ShowFindPanel.rawValue:
            return true
            
        // we allow next and previous if there is some search done
        case NSFindPanelAction.Next.rawValue:
            return mainSplitController!.searchProvider!.hasResult()
        case NSFindPanelAction.Previous.rawValue:
            return mainSplitController!.searchProvider!.hasResult()
            
        // we allow use selection if something is selected in the pdf view
        case NSFindPanelAction.SetFindString.rawValue:
            if let _ = pdfReader!.currentSelection() {
                return true
            }
            return false
            
        default:
            // in any other case, we check the action instead of tag
            switch menuItem.action.description {
                // these should always be enabled
                case "saveDocument:", "saveDocumentAs:", "tagShow:":
                return true
            default:
                // any other tag was not considered we disable it by default
                // we can print to check who else is calling this function using
                // print(menuItem.action)
                return false
            }
        }
    }
    
    // MARK: - Search panel
    
    @IBOutlet weak var searchTB: NSToolbarItem!
    @IBAction func toggleSearch(sender: NSToolbarItem) {
        mainSplitController?.toggleSearchPanel()
    }
    
    func focusOnSearch() {
        mainSplitController?.openSearchPanel()
    }
    
    func searchCollapseAction(wasCollapsed: Bool) {
        if wasCollapsed {
            searchTB.image = NSImage(named: PeyeConstants.searchButton_UP)
        } else {
            searchTB.image = NSImage(named: PeyeConstants.searchButton_DOWN)
        }
    }
    
    // MARK: - Thumbnail side expand / reduce
    
    @IBOutlet weak var thumbTB: NSToolbarItem!
    @IBAction func showSide(sender: NSToolbarItem) {
        docSplitController?.toggleThumbSide()
    }
    
    func sideCollapseAction(wasCollapsed: Bool) {
        if wasCollapsed {
            thumbTB.image = NSImage(named: PeyeConstants.thumbButton_UP)
        } else {
            thumbTB.image = NSImage(named: PeyeConstants.thumbButton_DOWN)
        }
    }
    
    // MARK: - Annotations
    
    @IBAction func toggleAnnotate(sender: AnyObject?) {
        if let delegate = clickDelegate {
            if delegate.getRecognizersState() {
                setAnnotate(false)
            } else {
                setAnnotate(true)
            }
        }
    }
    
    /// Set the annotate function to on (true) or off (false)
    func setAnnotate(toState: Bool) {
        if let annotateTB = tbAnnotate, delegate = clickDelegate {
            if toState {
                delegate.setRecognizersTo(true)
                annotateTB.image = NSImage(named: PeyeConstants.annotateButton_DOWN)
            } else {
                delegate.setRecognizersTo(false)
                annotateTB.image = NSImage(named: PeyeConstants.annotateButton_UP)
            }
        }
    }
    
    // MARK: - Reading tracking
    
    /// The user started, or resumed reading (e.g. this window became key, a scroll event
    /// finished, etc.).
    func startedReading() {
        // Tell the history manager to "start recording"
        HistoryManager.sharedManager.entry(self)
        lastStartedReading = NSDate()
    }
    
    /// The user stopped, or paused reading (e.g. this window lost key status, a scroll event
    /// started, etc.).
    func stoppedReading() {
        // Tell the history manager to "stop recording"
        HistoryManager.sharedManager.exit(self)
        lastStartedReading = nil
    }
    
    // MARK: - DiMe communication
    
    /// Sends a desktop event directly (which includes doc metadata) for the currently displayed pdf
    func sendDeskEvent() {
        if let sciDoc = pdfReader!.sciDoc {
            let deskEvent = DesktopEvent(sciDoc: sciDoc)
            HistoryManager.sharedManager.sendToDiMe(deskEvent)
        }
    }
    
    /// Retrieves current ReadingEvent (for HistoryManager)
    func getCurrentStatus() -> ReadingEvent? {
        return pdfReader!.getViewportStatus() as ReadingEvent?
    }
    
    // MARK: - Metadata window
    
    @IBAction func thisDocMdata(sender: AnyObject?) {
        // create metadata window, if currently nil
        if metadataWindowController == nil {
            metadataWindowController = AppSingleton.mainStoryboard.instantiateControllerWithIdentifier("MetadataWindow") as? MetadataWindowController
        }
        
        // show window controller for metadata and send data
        metadataWindowController?.showWindow(self)
        metadataWindowController?.setDoc(pdfReader!.document(), mainWC: self)
    }
    
    
    // MARK: - Saving
    
    func saveDocument(sender: AnyObject) {
        saveDocumentAs(sender)
    }
    
    func saveDocumentAs(sender: AnyObject) {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["pdf", "PDF"]
        panel.nameFieldStringValue = (document as? NSDocument)?.fileURL?.lastPathComponent ?? "Untitled"
        if panel.runModal() == NSFileHandlingPanelOKButton {
            pdfReader?.document().writeToURL(panel.URL)
            let documentController = NSDocumentController.sharedDocumentController() 
            documentController.openDocumentWithContentsOfURL(panel.URL!, display: true) { _ in
                // empty, nothing else to do (NSDocumentController will automacally link URL to NSDocument (pdf file)
            }
        }
    }
    
    // MARK: - Initialization
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // metadata disabled at start (will be enabled in checkMetadata(_) )
        tbMetadata.enabled = false
        
        let oldFrame = NSRect(origin: self.window!.frame.origin, size: NSSize(width: PeyeConstants.docWindowWidth, height: PeyeConstants.docWindowHeight))
        self.window!.setFrame(oldFrame, display: true)
        
        // Set reference to pdfReader for convenience by using references to children of this window
        let splV: NSSplitViewController = self.window?.contentViewController as! NSSplitViewController
        docSplitController = splV.childViewControllers[1] as? DocumentSplitController
        docSplitController?.sideCollapseDelegate = self
        pdfReader = docSplitController?.myPDFSideController?.pdfReader
        
        // Reference for click gesture recognizers
        clickDelegate = docSplitController?.myPDFSideController
        
        // Set reference to main split controller
        self.mainSplitController = self.contentViewController as? MainSplitController
        self.mainSplitController?.searchCollapseDelegate = self
        self.mainSplitController?.searchPanelController?.pdfReader = pdfReader
        
        pdfReader?.setAutoScales(true)
        
        // Set annotate on or off depending on preference
        let enableAnnotate: Bool = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefEnableAnnotate) as! Bool
        setAnnotate(enableAnnotate)
        
        // Create debug window
        if PeyeConstants.debugWindow {
            debugWindowController = AppSingleton.mainStoryboard.instantiateControllerWithIdentifier("DebugWindow") as? NSWindowController
            debugWindowController?.showWindow(self)
            debugController = (debugWindowController?.contentViewController as! DebugController)
            debugController?.setUpMonitors(pdfReader!, docWindow: self.window!)
        }
        
        // Prepare to receive events
        setUpObservers()
    }
    
    /// Loads the PDF document and stores metadata inside it. Must be called after setting current document's URL.
    /// Sends a notification that the document has been loaded, with the document as object.
    func loadDocument() {
        // Load document and display it
        var pdfDoc: PDFDocument
        
        if let document: NSDocument = self.document as? NSDocument {
            let url: NSURL = document.fileURL!
            
            // set NSDocument subclass fields
            let peyeDoc = self.document as! PeyeDocument
            
            pdfDoc = PDFDocument(URL: url)
            peyeDoc.pdfDoc = pdfDoc
            pdfReader!.setDocument(pdfDoc)
            
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.documentChangeNotification, object: self.document)
            }
            
            // Tell app singleton which screen size we are using
            if let screen = window?.screen {
                AppSingleton.screenRect = screen.frame
            }
            
            // Asynchronously fetch text from document (if no text is found, nill we be passed)
            pdfReader?.checkPlainText() {
                [weak self] result in
                self?.checkMetadata(result)
            }
        }
    }
    
    /// Asynchronously fetch metadata (including plain text) from PDF.
    /// Enables the toolbar item when done.
    private func checkMetadata(plainText: String?) {
        guard let pdfr = self.pdfReader, _ = self.document else {
            return
        }
        
        // check if there is text
        dispatch_async(dispatch_get_main_queue()) {
            if let _ = plainText {
                pdfr.containsRawString = true
                self.tbMetadata.image = NSImage(named: "NSStatusAvailable")
            } else {
                self.tbMetadata.image = NSImage(named: "NSStatusUnavailable")
            }
            self.tbMetadata.enabled = true
        }
        
        // Associate PDF view to info element
        let url = (self.document as! PeyeDocument).fileURL!
        guard let pdfDoc = pdfr.document() else {
            return
        }
        let sciDoc = ScientificDocument(uri: url.path!, plainTextContent: plainText, title: pdfDoc.getTitle(), authors: pdfDoc.getAuthorsAsArray(), keywords: pdfDoc.getKeywordsAsArray(), subject: pdfDoc.getSubject())
        pdfReader!.sciDoc = sciDoc
        
        // Download metadata if needed, and send to dime if found
        let showTime = dispatch_time(DISPATCH_TIME_NOW,
                                     Int64(1 * Double(NSEC_PER_SEC)))
        dispatch_after(showTime, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
            [weak self] in
            if (NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDownloadMetadata) as! Bool) {
                self?.pdfReader?.document()?.autoCrossref() {
                    _json in
                    if let json = _json {
                        // found crossref, use it
                        sciDoc.updateFields(fromCrossRef: json)
                        HistoryManager.sharedManager.sendToDiMe(sciDoc)
                    } else if let tit = self?.pdfReader?.document().getTitle() {
                        // if not, attempt to get title from document
                        sciDoc.title = tit
                        HistoryManager.sharedManager.sendToDiMe(sciDoc)
                    } else if let tit = self?.pdfReader?.document().guessTitle() {
                        // as a last resort, guess it
                        self?.pdfReader?.document().setTitle(tit)
                        sciDoc.title = tit
                        HistoryManager.sharedManager.sendToDiMe(sciDoc)
                    }
                    // Update debug controller with metadata
                    if let title = pdfDoc.getTitle() {
                        dispatch_async(dispatch_get_main_queue()) {
                            self?.debugController?.titleLabel.stringValue = title
                        }
                    }
                }
            }
        }
        
        // Send event regarding opening of file
        sendDeskEvent()
        
        startedReading()
    }
    
    
    /// Prepares all the notification centre observers + timers (will have to be removed when the window wants to close). See unSetObservers, these two methods should load / unload the same observers.
    private func setUpObservers() {
        
        // Get notifications from pdfview for window
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(autoAnnotateComplete(_:)), name: PeyeConstants.autoAnnotationComplete, object: self.pdfReader!)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(zoomChanged(_:)), name: PDFViewScaleChangedNotification, object: self.pdfReader!)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(frameChanged(_:)), name: NSViewFrameDidChangeNotification, object: self.pdfReader!)
        // Note: forced downcast below relies on "undocumented" view tree
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(scrollingChanged(_:)), name: NSViewBoundsDidChangeNotification, object: self.pdfReader!.subviews[0].subviews[0] as! NSClipView)
        
        // Get notifications from managed window
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(windowMoved(_:)), name: NSWindowDidMoveNotification, object: self.window)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(windowWillSwitchAway(_:)), name: NSWindowDidResignKeyNotification, object: self.window)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(windowWantsMain(_:)), name: NSWindowDidBecomeKeyNotification, object: self.window)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(windowOcclusionChange(_:)), name: NSWindowDidChangeOcclusionStateNotification, object: self.window)
        
        // Get notifications from midas manager
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(eyeStateCallback(_:)), name: PeyeConstants.eyesAvailabilityNotification, object: MidasManager.sharedInstance)
        
        // Set up regular timer
        dispatch_sync(DocumentWindowController.timerQueue) {
            if self.regularTimer == nil {
                self.regularTimer = NSTimer(timeInterval: PeyeConstants.regularSummaryEventInterval, target: self, selector: #selector(self.regularTimerFire(_:)), userInfo: nil, repeats: true)
                NSRunLoop.currentRunLoop().addTimer(self.regularTimer!, forMode: NSRunLoopCommonModes)
            }
        }
    }
    
    // MARK: - Timer callbacks
    
    /// The regular timer is a repeating timer that regularly submits a summary event to dime
    @objc private func regularTimerFire(regularTimer: NSTimer) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
            if let mpdf = self.pdfReader where self.totalReadingTime >= PeyeConstants.minTotalReadTime {
                let summaryEv = mpdf.makeSummaryEvent()
                summaryEv.readingTime = self.totalReadingTime
                HistoryManager.sharedManager.sendToDiMe(summaryEv) {
                    _, id in
                    mpdf.setSummaryId(id)
                }
            }
        }
    }
    
    // MARK: - Unloading
    
    /// This window is going to close, send exit event and send all paragraph data to HistoryManager as summary. Calls the given callback once done saving to dime.
    func unload(callback: (Void -> Void)? = nil) {
        guard closeToken == 0 else {
            return
        }
        closeToken += 1
        stoppedReading()
        self.unSetObservers()
        self.debugController?.unSetMonitors(self.pdfReader!, docWindow: self.window!)
        self.debugController?.view.window?.close()
        self.metadataWindowController?.close()
        // If dime is available, call the callback after the dime operation is done,
        // otherwise call the callback right now
        if HistoryManager.sharedManager.dimeAvailable {
            let ww = NSWindow()
            let wvc = AppSingleton.mainStoryboard.instantiateControllerWithIdentifier("WaitVC") as! WaitViewController
            ww.contentViewController = wvc
            wvc.someText = "Sending data to DiMe..."
            self.window!.beginSheet(ww, completionHandler: nil)
            // send data to dime
            if let mpdf = self.pdfReader where self.totalReadingTime >= PeyeConstants.minTotalReadTime {
                let summaryEv = mpdf.makeSummaryEvent()
                summaryEv.readingTime = self.totalReadingTime
                HistoryManager.sharedManager.sendToDiMe(summaryEv) {
                    _ in
                    // signal when done
                    dispatch_async(dispatch_get_main_queue()) {
                        self.pdfReader!.setDocument(nil)
                        self.pdfReader!.markings = nil
                        self.window!.endSheet(ww)
                        callback?()
                    }
                }
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.pdfReader!.setDocument(nil)
                    self.pdfReader!.markings = nil
                    self.window!.endSheet(ww)
                    callback?()
                }
            }
        } else {
            dispatch_async(dispatch_get_main_queue()) {
                self.pdfReader!.setDocument(nil)
                self.pdfReader!.markings = nil
                callback?()
            }
        }
    }
    
    /// Removes all the observers created in setUpObservers()
    private func unSetObservers() {
        
        // Remove notifications from pdfView
        
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PeyeConstants.autoAnnotationComplete, object: self.pdfReader!)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PDFViewScaleChangedNotification, object: self.pdfReader!)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSViewFrameDidChangeNotification, object: self.pdfReader!)
        // Note: forced downcast, etc.
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSViewBoundsDidChangeNotification, object: self.pdfReader!.subviews[0].subviews[0] as! NSClipView)
        
        // Remove notifications from managed window
        
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidMoveNotification, object: self.window)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidResignKeyNotification, object: self.window)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidBecomeKeyNotification, object: self.window)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidChangeOcclusionStateNotification, object: self.window)
        
        // Remove notifications from midas manager
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PeyeConstants.eyesAvailabilityNotification, object: MidasManager.sharedInstance)
        
        // Stop regular timer
        if let timer = regularTimer {
            dispatch_sync(DocumentWindowController.timerQueue) {
                    timer.invalidate()
            }
            regularTimer = nil
        }
    }
    
    // MARK: - Notification callbacks from managed pdf view
    
    @objc private func zoomChanged(notification: NSNotification) {
        startedReading()
    }
    
    @objc private func frameChanged(notification: NSNotification) {
        startedReading()
    }
    
    @objc private func scrollingChanged(notification: NSNotification) {
        startedReading()
    }
    
    // MARK: - Notification callbacks from window
    
    @objc private func windowMoved(notification: NSNotification) {
        startedReading()
    }
    
    /// Enables the annotate toolbar button when auto annotation is complete
    @objc private func autoAnnotateComplete(notification: NSNotification) {
        tbAnnotate.enabled = true
    }
    
    /// This method is called when the managed window wants to become main window
    @objc private func windowWantsMain(notification: NSNotification) {
        NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.documentChangeNotification, object: self.document)
        
        // Set up regular timer
        dispatch_sync(DocumentWindowController.timerQueue) {
            if self.regularTimer == nil {
                self.regularTimer = NSTimer(timeInterval: PeyeConstants.regularSummaryEventInterval, target: self, selector: #selector(self.regularTimerFire(_:)), userInfo: nil, repeats: true)
                NSRunLoop.currentRunLoop().addTimer(self.regularTimer!, forMode: NSRunLoopCommonModes)
            }
        }
        
        // If the relevant preference is set, send a DesktopEvent for the current document
        if (NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefSendEventOnFocusSwitch) as! Bool) {
            sendDeskEvent()
        } else if let sciDoc = self.pdfReader?.sciDoc {
            // otherwise just send an information element for the given document if the current document
            // does not have already an associated info elemen in dime
            let showTime = dispatch_time(DISPATCH_TIME_NOW,
                                         Int64(2 * Double(NSEC_PER_SEC)))
            dispatch_after(showTime, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
                DiMeFetcher.retrieveScientificDocument(sciDoc.id) {
                    scidoc in
                    if scidoc == nil {
                        HistoryManager.sharedManager.sendToDiMe(sciDoc)
                    }
                }
            }
        }
        
        startedReading()
    }
    
    /// Unused yet (probably not really needed as we already know when windowWillSwitchAway)
    @objc private func windowOcclusionChange(notification: NSNotification) {
        NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.occlusionChangeNotification, object: self.window)
    }
    
    /// The managed window will stop being key window
    @objc private func windowWillSwitchAway(notification: NSNotification) {
        stoppedReading()
        
        // Stop regular timer
        if let timer = regularTimer {
            dispatch_sync(DocumentWindowController.timerQueue) {
                    timer.invalidate()
            }
            regularTimer = nil
        }
    }
   
    // MARK: - Window delegate
    
    /// Ensures that the document window never gets bigger than the maximum
    /// allowed size when midas is active and stays within its boundaries.
    func windowDidResize(notification: NSNotification) {
        // only constrain if midas is active
        if MidasManager.sharedInstance.midasAvailable {
            if let window = notification.object as? NSWindow, screen = window.screen {
                let shrankRect = DocumentWindow.getConstrainingRect(forScreen: screen)
                let intersectedRect = shrankRect.intersect(window.frame)
                if intersectedRect != window.frame {
                    window.setFrame(intersectedRect, display: true)
                }
            }
        }
    }
    
    // MARK: - Notification callbacks from MidasManager
    
    /// Reacts to eye being lost / found. If status changes when this is
    /// key window, send exit / enter event as necessary
    @objc private func eyeStateCallback(notification: NSNotification) {
        if self.window!.keyWindow {
            let uInfo = notification.userInfo as! [String: AnyObject]
            let avail = uInfo["available"] as! Bool
            if avail {
                startedReading()
            } else {
                stoppedReading()
            }
        }
    }
}

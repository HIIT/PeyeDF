//
//  DocumentWindowController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 22/06/15.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Cocoa
import Foundation
import Quartz

/// Manages the "Document Window", which comprises two split views, one inside the other
class DocumentWindowController: NSWindowController, NSWindowDelegate, SideCollapseToggleDelegate, SearchPanelCollapseDelegate {
    
    /// The "global" GCD queue in which all timers are created / destroyed (to prevent potential memory leaks, they all run here)
    static let timerQueue = dispatch_queue_create("hiit.PeyeDF.DocumentWindowController.timerQueue", DISPATCH_QUEUE_SERIAL)
    
    /// Regular timer for this window
    var regularTimer: NSTimer?
    
    weak var pdfReader: MyPDFReader?
    weak var docSplitController: DocumentSplitController?
    weak var mainSplitController: MainSplitController?
    var debugController: DebugController?
    var debugWindowController: NSWindowController?
    @IBOutlet weak var tbMetadata: NSToolbarItem!
    @IBOutlet weak var tbAnnotate: NSToolbarItem!
    
    var metadataWindowController: MetadataWindowController?
    
    var clickDelegate: ClickRecognizerDelegate?
    
    // MARK: - Searching
    
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
                mainSplitController?.searchProvider?.doSearch(currentSelection.string())
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
                case "thisDocMdata:", "saveDocument:", "saveDocumentAs:":
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
        let annotateTB = sender as? NSToolbarItem
        if let delegate = clickDelegate {
            if delegate.getRecognizersState() {
                delegate.setRecognizersTo(false)
                annotateTB?.image = NSImage(named: PeyeConstants.annotateButton_UP)
            } else {
                delegate.setRecognizersTo(true)
                annotateTB?.image = NSImage(named: PeyeConstants.annotateButton_DOWN)
            }
        }
    }
    
    // MARK: - DiMe communication
    
    /// Sends a desktop event directly (which includes doc metadata) for the currently displayed pdf
    func sendDeskEvent() {
        let sciDoc = pdfReader!.sciDoc!
        let deskEvent = DesktopEvent(sciDoc: sciDoc)
        HistoryManager.sharedManager.sendToDiMe(deskEvent, endPoint: .Event)
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
        metadataWindowController?.setDoc(pdfReader!.document())
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
        
        // Create debug window
        debugWindowController = AppSingleton.mainStoryboard.instantiateControllerWithIdentifier("DebugWindow") as? NSWindowController
        debugWindowController?.showWindow(self)
        debugController = (debugWindowController?.contentViewController as! DebugController)
        debugController?.setUpMonitors(pdfReader!, docWindow: self.window!)
        
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
            
            pdfDoc = PDFDocument(URL: url)
            pdfReader!.setDocument(pdfDoc)
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.documentChangeNotification, object: self.document)
            }
        
            // NSDocument subclass
            let peyeDoc = self.document as! PeyeDocument
            peyeDoc.pdfDoc = pdfDoc
            // check if there is text
            if let _ = pdfDoc.getText() {
                pdfReader!.containsRawString = true
                tbMetadata.image = NSImage(named: "NSStatusAvailable")
            } else {
                tbMetadata.image = NSImage(named: "NSStatusUnavailable")
            }
            
            // Associate PDF view to info element
            let sciDoc = ScientificDocument(uri: url.path!, plainTextContent: pdfDoc.getText(), title: pdfDoc.getTitle(), authors: pdfDoc.getAuthorsAsArray(), keywords: pdfDoc.getKeywordsAsArray())
            pdfReader!.sciDoc = sciDoc
            
            // Tell app singleton which screen size we are using
            if let screen = window?.screen {
                AppSingleton.screenRect = screen.frame
            }
            
            // Update debug controller with metadata
            if let title = pdfDoc.getTitle() {
                debugController?.titleLabel.stringValue = title
            }
            
            // Send event regardig opening of file
            sendDeskEvent()
            
        }
    }
    
    
    /// Prepares all the notification centre observers + timers (will have to be removed when the window wants to close). See unSetObservers, these two methods should load / unload the same observers.
    private func setUpObservers() {
        
        // Get notifications from pdfview for window
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "autoAnnotateComplete:", name: PeyeConstants.autoAnnotationComplete, object: self.pdfReader!)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "zoomChanged:", name: PDFViewScaleChangedNotification, object: self.pdfReader!)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "frameChanged:", name: NSViewFrameDidChangeNotification, object: self.pdfReader!)
        // Note: forced downcast below relies on "undocumented" view tree
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "scrollingChanged:", name: NSViewBoundsDidChangeNotification, object: self.pdfReader!.subviews[0].subviews[0] as! NSClipView)
        
        // Get notifications from managed window
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowMoved:", name: NSWindowDidMoveNotification, object: self.window)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowWillSwitchAway:", name: NSWindowDidResignKeyNotification, object: self.window)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowWantsMain:", name: NSWindowDidBecomeKeyNotification, object: self.window)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowOcclusionChange:", name: NSWindowDidChangeOcclusionStateNotification, object: self.window)
        
        // Get notifications from midas manager
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "eyeStateCallback:", name: PeyeConstants.eyesAvailabilityNotification, object: MidasManager.sharedInstance)
        
        // Set up regular timer
        dispatch_sync(DocumentWindowController.timerQueue) {
            if self.regularTimer == nil {
                self.regularTimer = NSTimer(timeInterval: PeyeConstants.regularSummaryEventInterval, target: self, selector: "regularTimerFire:", userInfo: nil, repeats: true)
                NSRunLoop.currentRunLoop().addTimer(self.regularTimer!, forMode: NSRunLoopCommonModes)
            }
        }
    }
    
    // MARK: - Timer callbacks
    
    /// The regular timer is a repeating timer that regularly submits a summary event to dime
    @objc private func regularTimerFire(regularTimer: NSTimer) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
            if let mpdf = self.pdfReader, userRectStatus = mpdf.getUserRectStatus() {
                HistoryManager.sharedManager.sendToDiMe(userRectStatus, endPoint: .Event) {
                    id in
                    mpdf.setSummaryId(id)
                }
            }
        }
    }
    
    // MARK: - Unloading
    
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
        // Tell the history manager to "start recording"
        HistoryManager.sharedManager.entry(self)
    }
    
    @objc private func frameChanged(notification: NSNotification) {
        // Tell the history manager to "start recording"
        HistoryManager.sharedManager.entry(self)
    }
    
    @objc private func scrollingChanged(notification: NSNotification) {
        // Tell the history manager to "start recording"
        HistoryManager.sharedManager.entry(self)
    }
    
    // MARK: - Notification callbacks from window
    
    @objc private func windowMoved(notification: NSNotification) {
        // Tell the history manager to "start recording"
        HistoryManager.sharedManager.entry(self)
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
                self.regularTimer = NSTimer(timeInterval: PeyeConstants.regularSummaryEventInterval, target: self, selector: "regularTimerFire:", userInfo: nil, repeats: true)
                NSRunLoop.currentRunLoop().addTimer(self.regularTimer!, forMode: NSRunLoopCommonModes)
            }
        }
        
        // If the relevant preference is set, send a DesktopEvent for the current document
        if (NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefSendEventOnFocusSwitch) as! Bool) {
            sendDeskEvent()
        } else {
            // otherwise just send an information element for the given document if the current document
            // does not have already an associated info elemen in dime
            DiMeFetcher.retrieveScientificDocument(pdfReader!.sciDoc!.id) {
                scidoc in
                if scidoc == nil {
                    HistoryManager.sharedManager.sendToDiMe(self.pdfReader!.sciDoc!, endPoint: .InformationElement)
                }
            }
        }
        
        // Tell the history manager to "start recording"
        HistoryManager.sharedManager.entry(self)
    }
    
    /// Unused yet (probably not really needed as we already know when windowWillSwitchAway)
    @objc private func windowOcclusionChange(notification: NSNotification) {
        NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.occlusionChangeNotification, object: self.window)
    }
    
    /// The managed window will stop being key window
    @objc private func windowWillSwitchAway(notification: NSNotification) {
        // Tell the history manager to "stop recording"
        HistoryManager.sharedManager.exit(self)
        
        // Stop regular timer
        if let timer = regularTimer {
            dispatch_sync(DocumentWindowController.timerQueue) {
                    timer.invalidate()
            }
            regularTimer = nil
        }
    }
   
    // MARK: - Window delegate
    // DocumentWindowController is the delegate of DocumentWindow
    
    /// This window is going to close, send exit event and send all paragraph data to HistoryManager as summary
    func windowShouldClose(sender: AnyObject) -> Bool {
        HistoryManager.sharedManager.exit(self)
        unSetObservers()
        debugController?.unSetMonitors(pdfReader!, docWindow: self.window!)
        debugController?.view.window?.close()
        metadataWindowController?.close()
        if HistoryManager.sharedManager.dimeAvailable {
            let ww = NSWindow()
            let wvc = AppSingleton.mainStoryboard.instantiateControllerWithIdentifier("WaitVC") as! WaitViewController
            ww.contentViewController = wvc
            wvc.someText = "Sending data to DiMe..."
            self.window!.beginSheet(ww, completionHandler: nil)
            // send data to dime
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                if let mpdf = self.pdfReader, userRectStatus = mpdf.getUserRectStatus() {
                    HistoryManager.sharedManager.sendToDiMe(userRectStatus, endPoint: .Event)
                }
                dispatch_sync(dispatch_get_main_queue()) {
                    AppSingleton.appDelegate.openPDFs--
                    ww.close()
                    self.window!.close()
                }
            }
            return false
        } else {
            return true
        }
    }
    
    func windowWillClose(notification: NSNotification) {
        AppSingleton.appDelegate.openPDFs--
    }
    
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
                HistoryManager.sharedManager.entry(self)
            } else {
                HistoryManager.sharedManager.exit(self)
            }
        }
    }
}

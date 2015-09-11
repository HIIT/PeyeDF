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
class DocumentWindowController: NSWindowController, SideCollapseToggleDelegate, SearchPanelCollapseDelegate {
    
    @IBOutlet weak var selectButton: NSToolbarItem!
    weak var myPdf: MyPDF?
    weak var docSplitController: DocumentSplitController?
    weak var mainSplitController: MainSplitController?
    var debugController: DebugController?
    var debugWindowController: NSWindowController?
    @IBOutlet weak var docStatus: NSToolbarItem!
    @IBOutlet weak var tbAnnotate: NSToolbarItem!
    
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
            if let currentSelection = myPdf!.currentSelection() {
                mainSplitController?.searchProvider?.doSearch(currentSelection.string())
                mainSplitController?.openSearchPanel()
            }
        default:
            let exception = NSException(name: "Unimplemented search function", reason: "Enum raw value not recognized", userInfo: nil)
            exception.raise()
        }
    }
    
    /// Checks if the find next and find previous item should be enabled
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
            if let currentSelection = myPdf!.currentSelection() {
                return true
            }
            return false
            
        // nothing else should appear because we only implement performFindPanelAction(_)
        default:
            // any other tag was not considered and should not be enabled
            return false
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
        let infoElem = myPdf!.infoElem!
        let deskEvent = DesktopEvent(infoElem: infoElem)
        HistoryManager.sharedManager.sendToDiMe(deskEvent as Event)
    }
    
    /// Retrieves current ReadingEvent (for HistoryManager)
    func getCurrentStatus() -> ReadingEvent? {
        return myPdf!.getStatus() as ReadingEvent?
    }
    
    // MARK: - Debug functions
    
    @IBAction func sendToDiMe(sender: AnyObject?) {
        let readingEvent:ReadingEvent = myPdf!.getStatus()!  // assuming there is a non-nil status if we press the button
        HistoryManager.sharedManager.sendToDiMe(readingEvent as Event)
    }
    
    @IBAction func selectVisibleText(sender: AnyObject?) {
        myPdf?.selectVisibleText(sender)
    }
    
    @IBAction func thisDocMdata(sender: AnyObject) {
        if let mainWin = NSApplication.sharedApplication().mainWindow {
            let peyeDoc: PeyeDocument = NSDocumentController.sharedDocumentController().documentForWindow(mainWin) as! PeyeDocument
            let myAl = NSAlert()
            
            
            var allTextHead = "** NO TEXT FOUND **"
            if let aText = peyeDoc.trimmedText {  // we assume no text if this is nil
                let ei = advance(aText.startIndex, 500)
                allTextHead = aText.substringToIndex(ei)
            }
            myAl.messageText = "Filename: \(peyeDoc.filename)\nTitle: \(peyeDoc.title)\nAuthor(s):\(peyeDoc.authors)"
            myAl.informativeText = "All text (first 500 chars):\n" + allTextHead
            myAl.beginSheetModalForWindow(mainWin, completionHandler: nil)
        }
    }
    
    
    // MARK: - Saving
    
    func saveDocument(sender: AnyObject) {
        saveDocumentAs(sender)
    }
    
    func saveDocumentAs(sender: AnyObject) {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["pdf", "PDF"]
        if panel.runModal() == NSFileHandlingPanelOKButton {
            myPdf?.document().writeToURL(panel.URL)
            let documentController = NSDocumentController.sharedDocumentController() as! NSDocumentController
            documentController.openDocumentWithContentsOfURL(panel.URL!, display: true) { _ in
                // empty, nothing else to do (NSDocumentController will automacally link URL to NSDocument (pdf file)
            }
        }
    }
    
    // MARK: - Initialization
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        var oldFrame = NSRect(origin: self.window!.frame.origin, size: NSSize(width: PeyeConstants.docWindowWidth, height: PeyeConstants.docWindowHeight))
        self.window!.setFrame(oldFrame, display: true)
        
        // Set reference to myPdf for convenience by using references to children of this window
        let splV: NSSplitViewController = self.window?.contentViewController as! NSSplitViewController
        docSplitController = splV.childViewControllers[1] as? DocumentSplitController
        docSplitController?.sideCollapseDelegate = self
        myPdf = docSplitController?.myPDFSideController?.myPDF
        
        // Reference for click gesture recognizers
        clickDelegate = docSplitController?.myPDFSideController
        
        // Set reference to main split controller
        self.mainSplitController = self.contentViewController as? MainSplitController
        self.mainSplitController?.searchCollapseDelegate = self
        self.mainSplitController?.searchPanelController?.pdfView = myPdf
        
        myPdf?.setAutoScales(true)
        
        // Create debug window
        debugWindowController = AppSingleton.storyboard.instantiateControllerWithIdentifier("DebugWindow") as? NSWindowController
        debugWindowController?.showWindow(self)
        debugController = (debugWindowController?.contentViewController as! DebugController)
        debugController?.setUpMonitors(myPdf!, docWindow: self.window!)
        self.showWindow(self)
        
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
            let doc:PDFDocument = PDFDocument(URL: url)
            
            pdfDoc = PDFDocument(URL: url)
            myPdf?.setDocument(pdfDoc)
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.documentChangeNotification, object: self.document)
            }
        
            // Put metadata into NSDocument subclass for convenience
            let peyeDoc = self.document as! PeyeDocument
            let docAttrib = pdfDoc.documentAttributes()
            if let title: AnyObject = docAttrib[PDFDocumentTitleAttribute] {
                peyeDoc.title = title as! String
            }
            if let auth: AnyObject = docAttrib[PDFDocumentAuthorAttribute] {
                peyeDoc.authors = auth as! String
            }
            var trimmedText = pdfDoc.string()
            trimmedText = trimmedText.stringByReplacingOccurrencesOfString("\u{fffc}", withString: "")
            trimmedText = trimmedText.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) // get trimmed version of all text
            trimmedText = trimmedText.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet()) // trim newlines
            trimmedText = trimmedText.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) // trim again
            if count(trimmedText) > 5 {  // we assume the document does contain useful text if there are more than 5 characters remaining
                peyeDoc.trimmedText = trimmedText
                peyeDoc.sha1 = trimmedText.sha1()
                myPdf?.containsRawString = true
                docStatus.image = NSImage(named: "NSStatusAvailable")
            } else {
                docStatus.image = NSImage(named: "NSStatusUnavailable")
            }
            
            // Associate PDF view to info element
            var plainText = "** No text **"
            if let inputText = peyeDoc.trimmedText {
                plainText = inputText
            }
            let infoElem = DocumentInformationElement(uri: url.path!, id: peyeDoc.sha1!, plainTextContent: plainText, title: peyeDoc.title)
            myPdf?.infoElem = infoElem
            
            // Update debug controller with metadata
            debugController?.titleLabel.stringValue = peyeDoc.title
            
            // Send event regardig opening of file
            sendDeskEvent()
            
            // To make keystroke shortcuts work
            myPdf?.becomeFirstResponder()
        }
    }
    
    
    /// Prepares all the notification centre observers (will have to be removed when the window wants to close). See unSetObservers, these two methods should load / unload the same observers.
    private func setUpObservers() {
        
        // Get notifications from pdfview for window
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "autoAnnotateComplete:", name: PeyeConstants.autoAnnotationComplete, object: self.myPdf!)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "zoomChanged:", name: PDFViewScaleChangedNotification, object: self.myPdf!)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "frameChanged:", name: NSViewFrameDidChangeNotification, object: self.myPdf!)
        // Note: forced downcast below relies on "undocumented" view tree
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "scrollingChanged:", name: NSViewBoundsDidChangeNotification, object: self.myPdf!.subviews[0].subviews[0] as! NSClipView)
        
        // Get notifications from managed window
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowMoved:", name: NSWindowDidMoveNotification, object: self.window)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowWillSwitchAway:", name: NSWindowDidResignMainNotification, object: self.window)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowWantsMain:", name: NSWindowDidBecomeMainNotification, object: self.window)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowWantsClose:", name: NSWindowWillCloseNotification, object: self.window)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowOcclusionChange:", name: NSWindowDidChangeOcclusionStateNotification, object: self.window)
    }
    
    // MARK: - Unloading
    
    /// Removes all the observers created in setUpObservers()
    private func unSetObservers() {
        
        // Remove notifications from pdfView
        
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PeyeConstants.autoAnnotationComplete, object: self.myPdf!)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PDFViewScaleChangedNotification, object: self.myPdf!)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSViewFrameDidChangeNotification, object: self.myPdf!)
        // Note: forced downcast, etc.
        NSNotificationCenter.defaultCenter().removeObserver(self, name:             NSViewBoundsDidChangeNotification, object: self.myPdf!.subviews[0].subviews[0] as! NSClipView)
        
        // Remove notifications from managed window
        
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidMoveNotification, object: self.window)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidResignMainNotification, object: self.window)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidBecomeMainNotification, object: self.window)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowWillCloseNotification, object: self.window)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidChangeOcclusionStateNotification, object: self.window)
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
        
        // If the relevant preference is set, send a DesktopEvent for the current document
        if (NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefSendEventOnFocusSwitch) as! Bool) {
            sendDeskEvent()
        }
        
        // Tell the history manager to "start recording"
        HistoryManager.sharedManager.entry(self)
    }
    
    /// Unused yet (probably not really needed as we already know when windowWillSwitchAway)
    @objc private func windowOcclusionChange(notification: NSNotification) {
        NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.occlusionChangeNotification, object: self.window)
    }
    
    /// The managed window will stop being main window
    @objc private func windowWillSwitchAway(notification: NSNotification) {
        // Tell the history manager to "stop recording"
        HistoryManager.sharedManager.exit(self)
    }
    
    /// This window is going to close, release all references (importantly, remove notification observers)
    @objc private func windowWantsClose(notification: NSNotification) {
        unSetObservers()
        debugController?.unSetMonitors(myPdf!, docWindow: self.window!)
        debugController?.view.window?.close()
        myPdf?.setDocument(nil)
    }
}

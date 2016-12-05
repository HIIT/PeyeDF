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
class DocumentWindowController: NSWindowController, NSWindowDelegate, SideCollapseToggleDelegate, SearchPanelCollapseDelegate, TagDelegate, NSPopoverDelegate {
    
    /// The "global" GCD queue in which all timers are created / destroyed (to prevent potential memory leaks, they all run here)
    static let timerQueue = DispatchQueue(label: "hiit.PeyeDF.DocumentWindowController.timerQueue", attributes: [])
    
    /// Regular timer for this window
    var regularTimer: Timer?
    
    /// When the user started reading (stoppedReading date - this date = reading time).
    /// Should be set to nil when the user stops reading, or on startup.
    /// Setting this value to a new value automatically increases the totalReadingTime
    /// (takes into consideration minimum reading values constants)
    var lastStartedReading: Date? {
        didSet {
            // increase total reading time constant if reading time was below minimum.
            // if reading time was above maximum, increase by maximum
            if let rdate = oldValue {
                let rTime = Date().timeIntervalSince(rdate)
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
    var totalReadingTime: TimeInterval = 0
    
    /// To make sure only one summary event is sent to dime
    var closeToken: Int = 0
    
    weak var pdfReader: PDFReader?
    weak var docSplitController: DocumentSplitController?
    weak var mainSplitController: MainSplitController?
    @IBOutlet weak var tbDocument: NSToolbarItem!
    @IBOutlet weak var tbAnnotate: NSToolbarItem!
    
    var metadataWindowController: MetadataWindowController?
    
    weak var readerDelegate: PDFReaderDelegate?
    
    // MARK: - Tagging
    
    @IBOutlet weak var tbTagButton: NSButton!
    @IBOutlet weak var tbTagItem: NSToolbarItem!
    
    fileprivate var currentTagOperation: TagOperation = .none
    
    lazy var popover: NSPopover = {
        let pop = NSPopover()
        pop.behavior = NSPopoverBehavior.transient
        let tvc = AppSingleton.tagsStoryboard.instantiateController(withIdentifier: "TagViewController")
        pop.contentViewController = tvc as! TagViewController
        pop.delegate = self
        return pop
    }()
    
    @IBAction func tagShow(_ sender: AnyObject?) {
        
        // Skip if dime is out
        guard DiMeSession.dimeAvailable else {
            return
        }
        
        DispatchQueue.main.async {
            
            let tvc = self.popover.contentViewController as! TagViewController
            tvc.tagDelegate = self // prepare to receive tag updates
            
            // if popover is not shown, show it, otherwise close it
            
            if !self.popover.isShown {
                
                // decide what to do when popover appears
                // if the pdfReader wants to show it in relation to tags,
                // retrieve tags from it and show them
                // if not, if the current selection is empty, show tags for document
                // lastly, if there is a selection, show tags corresponding to that selection
                if let clickTags = self.pdfReader!.currentlyClickedOnTags() {
                    
                    // tag pdfReader's currently selected tag
                    
                    let edge: NSRectEdge
                    
                    // use first tag to get rect encompassing the whole tagged paragraph
                    let tagRect = clickTags[0].rRects.reduce(NSRect(), {
                        p, r in
                        let page = self.pdfReader!.document!.page(at: Int(r.pageIndex))
                        let pageRect = self.pdfReader!.convert(r.rect, from: page!)
                        return NSUnionRect(p, pageRect)
                    })
                    
                    if (tagRect.minX + tagRect.size.width / 2) > self.pdfReader!.bounds.width / 2 {
                        edge = NSRectEdge.maxX
                    } else {
                        edge = NSRectEdge.minX
                    }
                    
                    self.popover.show(relativeTo: tagRect, of: self.pdfReader!, preferredEdge: edge)
                    
                    tvc.setStatus(false)
                    
                    tvc.setTags(clickTags)
                    
                    self.currentTagOperation = .previousReading(clickTags)
                    
                } else if (self.pdfReader!.currentSelection?.string!.trimmed().isEmpty ?? true) {
                    
                    // document-level tagging
                    
                    self.popover.show(relativeTo: self.tbTagButton.bounds, of: self.tbTagButton, preferredEdge: NSRectEdge.minY)
                    tvc.setStatus(true)
                    
                    // refresh document tags if different from what's stored
                    if tvc.representedTags != self.pdfReader!.sciDoc!.tags.map({$0.text}) {
                        tvc.setTags(self.pdfReader!.sciDoc!.tags)
                    }
                    
                    self.currentTagOperation = .document
                    
                } else {
                    
                    // manual selection tagging
                    
                    let edge: NSRectEdge
                    
                    // selection's tag popover is shown on the right edge if selection's rect mid > pdf reader rect mid
                    guard let sel = self.pdfReader!.currentSelection else {
                        return
                    }
                    var selBounds = sel.bounds(for: sel.pages[0] )
                    selBounds = self.pdfReader!.convert(selBounds, from: sel.pages[0] )
                    if (selBounds.minX + selBounds.size.width / 2) > self.pdfReader!.bounds.width / 2 {
                        edge = NSRectEdge.maxX
                    } else {
                        edge = NSRectEdge.minX
                    }
                    self.popover.show(relativeTo: selBounds, of: self.pdfReader!, preferredEdge: edge)
                    
                    tvc.setStatus(false)
                    
                    self.currentTagOperation = TagOperation.manualSelection(sel)
                    
                    // set tags in popup
                    let (selRects, selIdxs) = self.pdfReader!.getLineRects(sel)
                    if let cTags = self.pdfReader!.sciDoc?.tags.getReadingTags(selRects, onPages: selIdxs) {
                        tvc.setTags(cTags)
                    }
                }
                
            } else {
                self.currentTagOperation = .none
                self.popover.performClose(self)
            }
        }
    }
    
    /// Exports all readingtags (tags referring to blocks of text) to a json
    /// file specified by the user.
    @IBAction func exportReadingTags(_ sender: AnyObject?) {
        guard let pdfReader = self.pdfReader, let win = self.window
          , pdfReader.readingTags.count > 0 else {
            AppSingleton.alertUser("Could not find any text-related tags")
            return
        }
        
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["json", "JSON"]
        panel.canSelectHiddenExtension = true
        panel.nameFieldStringValue = "\((self.document as! PeyeDocument).fileURL!.deletingPathExtension().lastPathComponent)-Tags.json"
        panel.beginSheetModal(for: win, completionHandler: {
            result in
            if result == NSFileHandlingPanelOKButton {
                let outURL = panel.url!
                let options = JSONSerialization.WritingOptions.prettyPrinted
                
                do {
                    let outDict = pdfReader.readingTags.flatMap({$0.getDict()}) as AnyObject
                    let outData = try JSONSerialization.data(withJSONObject: outDict, options: options)
                    
                    // create output file if it doesn't exist
                    if !FileManager.default.fileExists(atPath: outURL.path) {
                        FileManager.default.createFile(atPath: outURL.path, contents: nil, attributes: nil)
                    } else {
                    // if file exists, delete it and create id
                        do {
                            try FileManager.default.removeItem(at: outURL)
                            FileManager.default.createFile(atPath: outURL.path, contents: nil, attributes: nil)
                        } catch {
                            AppSingleton.log.error("Could not delete file at \(outURL): \(error)")
                        }
                    }
                    
                    // write data to existing file
                    do {
                        let file = try FileHandle(forWritingTo: outURL)
                        file.write(outData)
                    } catch {
                        AppSingleton.alertUser("Error while creating output file", infoText: "\(error)")
                    }
                    
                } catch {
                    AppSingleton.alertUser("Error while serializing json", infoText: "\(error)")
                }
            }
        })
    }
    
    /// Acknowledges that a tag was added, updates scientific document accordingly and sends message to peers
    func tagAdded(_ theTag: String) {
        switch currentTagOperation {
        case .document:
            // simple tag
            pdfReader?.sciDoc?.addTag(theTag)
        case .manualSelection(let sel):
            let (rects, idxs) = pdfReader!.getLineRects(sel)
            if rects.count > 0 {
                let sdTag = ReadingTag(text: theTag, withRects: rects, pages: idxs, pdfBase: self.pdfReader)
                pdfReader?.sciDoc?.addTag(sdTag)  // add reading tag to scidoc
                CollaborationMessage.addReadingTag(sdTag).sendToAll()  // tell peers we added this tag
            }
        case .previousReading(let readingTags):
            let theTag = ReadingTag(withText: theTag, fromTag: readingTags[0])
            pdfReader?.sciDoc?.addTag(theTag)  // add reading tag to scidoc
            CollaborationMessage.addReadingTag(theTag).sendToAll()  // tell peers we added this tag
        case .none:
            AppSingleton.log.error("Adding a tag when no tags are currently being edited")
        }
    }
    
    /// Acknowledges that a tag was removed, updates scientific document accordingly and sends message to peers
    func tagRemoved(_ theTag: String) {
        switch currentTagOperation {
        case .document:
            pdfReader?.sciDoc?.removeTag(theTag)
        case .manualSelection(let sel):
            if let tags = pdfReader?.tagsForSelection(sel) , tags.count > 0 {
                let (rects, idxs) = pdfReader!.getLineRects(sel)
                if rects.count > 0 {
                    let sdTag = ReadingTag(text: theTag, withRects: rects, pages: idxs, pdfBase: self.pdfReader)
                    pdfReader?.sciDoc?.subtractTag(sdTag)  // remove tag from scidoc
                    CollaborationMessage.removeReadingTag(sdTag).sendToAll()  // tell peers we removed this tag
                }
            }
        case .previousReading(let readingTags):
            let theTag = ReadingTag(withText: theTag, fromTag: readingTags[0])
            pdfReader?.sciDoc?.subtractTag(theTag)  // remove tag from scidoc
            CollaborationMessage.removeReadingTag(theTag).sendToAll()  // tell peers we removed this tag
        case .none:
            AppSingleton.log.error("Removing a tag when no tags are currently being edited")
        }
    }
    
    /// Searches for a tag's text
    func tagInfo(_ theTag: String) {
        doSearch(TagConstants.tagSearchPrefix + theTag, exact: false)
    }
    
    func isNextTagReading() -> Bool {
        switch currentTagOperation {
        case .previousReading, .manualSelection:
             return true
        default:
            return false
        }
    }
    
    /// Implemented to detect when the tag popover is closed (to clear current tag)
    func popoverWillClose(_ notification: Notification) {
        self.currentTagOperation = .none
        pdfReader!.clearClickedOnTags()
    }
    
    // MARK: - Searching
    
    /// Do a search using a predefined string (when called from outside ui, e.g. from other applications)
    /// - parameter exact: If true, searches for exact phrase (false for all words)
    func doSearch(_ searchString: String, exact: Bool) {
        DispatchQueue.main.async {
            self.mainSplitController?.openSearchPanel()
            AppSingleton.findPasteboard.stringValue = searchString
        }
        // wait a very short amount to allow loading and display of views
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
            self.mainSplitController?.searchPanelController!.doSearch(searchString, exact: exact)
        }
    }
    
    /// Perform search using default methods.
    @objc func performFindPanelAction(_ sender: AnyObject) {
        switch UInt(sender.tag) {
        case NSFindPanelAction.showFindPanel.rawValue:
            focusOnSearch()
        case NSFindPanelAction.next.rawValue:
            mainSplitController?.searchProvider?.selectNextResult(nil)
        case NSFindPanelAction.previous.rawValue:
            mainSplitController?.searchProvider?.selectPreviousResult(nil)
        case NSFindPanelAction.setFindString.rawValue:
            if let currentSelection = pdfReader!.currentSelection {
                mainSplitController?.searchProvider?.doSearch(currentSelection.string!, exact: true)
                mainSplitController?.openSearchPanel()
            }
        default:
            let exception = NSException(name: NSExceptionName(rawValue: "Unimplemented search function"), reason: "Enum raw value not recognized", userInfo: nil)
            exception.raise()
        }
    }
    
    // MARK: - Menu validation
    
    /// Checks which menu items should be enabled (some logic used for find next and previous menu items).
    @objc override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch UInt(menuItem.tag) {
            
        // we always allow find
        case NSFindPanelAction.showFindPanel.rawValue:
            return true
            
        // we allow next and previous if there is some search done
        case NSFindPanelAction.next.rawValue:
            return mainSplitController!.searchProvider!.hasResult()
        case NSFindPanelAction.previous.rawValue:
            return mainSplitController!.searchProvider!.hasResult()
            
        // we allow use selection if something is selected in the pdf view
        case NSFindPanelAction.setFindString.rawValue:
            if let _ = pdfReader!.currentSelection {
                return true
            }
            return false
            
        case TagConstants.tagMenuTag:
            return DiMeSession.dimeAvailable
            
        case PeyeConstants.annotateMenuClearHighlightTag:
            return (pdfReader?.documentLoaded ?? false) && (pdfReader?.urlRects.count ?? 0) != 0
            
        default:
            // in any other case, we check the action instead of tag
            if let action = menuItem.action {
                switch action.description {
                    // these should always be enabled
                    case "saveDocument:", "saveDocumentAs:", "exportReadingTags:":
                    return true
                default:
                    // any other tag was not considered we disable it by default
                    // we can print to check who else is calling this function using
                    // print(menuItem.action)
                    return false
                }
            } else {
                return false
            }
        }
    }
    
    // MARK: - Search panel
    
    @IBOutlet weak var searchTB: NSToolbarItem!
    @IBAction func toggleSearch(_ sender: NSToolbarItem) {
        mainSplitController?.toggleSearchPanel()
    }
    
    func focusOnSearch() {
        mainSplitController?.openSearchPanel()
    }
    
    func searchCollapseAction(_ wasCollapsed: Bool) {
        if wasCollapsed {
            searchTB.image = NSImage(named: PeyeConstants.searchButton_UP)
        } else {
            searchTB.image = NSImage(named: PeyeConstants.searchButton_DOWN)
        }
    }
    
    // MARK: - Thumbnail side expand / reduce
    
    @IBOutlet weak var thumbTB: NSToolbarItem!
    @IBAction func showSide(_ sender: NSToolbarItem) {
        docSplitController?.toggleThumbSide()
    }
    
    func sideCollapseAction(_ wasCollapsed: Bool) {
        if wasCollapsed {
            thumbTB.image = NSImage(named: PeyeConstants.thumbButton_UP)
        } else {
            thumbTB.image = NSImage(named: PeyeConstants.thumbButton_DOWN)
        }
    }
    
    // MARK: - Annotations

    @IBAction func clearHighlights(_ sender: AnyObject?) {
        pdfReader?.urlRects = []
    }

    @IBAction func toggleAnnotate(_ sender: AnyObject?) {
        if let delegate = readerDelegate {
            if delegate.getRecognizersState() {
                setAnnotate(false)
            } else {
                setAnnotate(true)
            }
        }
    }
    
    /// Set the annotate function to on (true) or off (false)
    func setAnnotate(_ toState: Bool) {
        if let annotateTB = tbAnnotate, let delegate = readerDelegate {
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
    
    /// Prepares to start tracking.
    /// Tells multipeer that this window is associated to the found contentHash (if file has text).
    func startTracking() {
        guard let pdfr = self.pdfReader, let sciDoc = pdfr.sciDoc else {
            AppSingleton.log.error("Could not find pdfReader and valid scientific document")
            return
        }
        
        // Set tag button and toolbar status to DiMe's status
        self.tbTagButton.isEnabled = DiMeSession.dimeAvailable
        self.tbTagItem.isEnabled = DiMeSession.dimeAvailable
        
        // Operations which require a document to have a content hash
        if let cHash = sciDoc.contentHash {
            // tell multipeer about the contenthash related to the file we have open in this window
            Multipeer.ourWindows[cHash] = self
            
            // if the relevant preference is set, fetch all summaryreadingevents which are associated to this document and display the annotations in those
            if (UserDefaults.standard.object(forKey: PeyeConstants.prefLoadPreviousAnnotations) as! Bool) {
                let showTime = DispatchTime.now() + 0.5  // half second later
                DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).asyncAfter(deadline: showTime) {
                    [weak self] in
                    DiMeFetcher.retrieveAllManualReadingRects(forSciDoc: sciDoc) {
                        // disable button until operation is complete
                        self?.window?.standardWindowButton(.closeButton)?.isEnabled = false
                        $0.forEach() {
                            pdfr.markings.addRect($0)
                        }
                        pdfr.autoAnnotate()
                        // re enable close button once all data has been retrieved
                        self?.window?.standardWindowButton(.closeButton)?.isEnabled = true
                    }
                }
            }
        }
        
        // Download metadata if needed, and send to dime if we want this and is found
        // Dispatch this on utility queue because crossref request blocks.
        let showTime = DispatchTime.now() + 1  // one second later
        DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).asyncAfter(deadline: showTime) {
            [weak self] in
            
            if (UserDefaults.standard.object(forKey: PeyeConstants.prefDownloadMetadata) as! Bool),
                let json = pdfr.document?.autoCrossref() {
                // found crossref, use it
                sciDoc.updateFields(fromCrossRef: json)
            } else if let tit = pdfr.document?.getTitle() {
                // if not, attempt to get title from document
                sciDoc.title = tit
            } else if let tit = pdfr.document?.guessTitle() {
                // as a last resort, guess it
                pdfr.document?.setTitle(tit)
                sciDoc.title = tit
            }
            self?.sendAndUpdateScidoc(sciDoc)
        }
        
        // Send event regarding opening of file
        sendDeskEvent()
        
        startedReading()
    }
    
    /// The user started, or resumed reading (e.g. this window became key, a scroll event
    /// finished, etc.).
    func startedReading() {
        // do not do anything if we are closing
        guard closeToken == 0 else {
            return
        }
        
        // Tell the history manager to "start recording"
        HistoryManager.sharedManager.entry(self)
        lastStartedReading = Date()
        
        // Send current position to peers, if connected
        if Multipeer.session.connectedPeers.count > 0, let cp = pdfReader?.getCurrentPoint() {
            CollaborationMessage.scrollTo(area: cp).sendToAll(.unreliable)
        }
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
            DiMePusher.sendToDiMe(deskEvent)
        }
    }
    
    /// Acknowledges that the user has been looking at this part of a document
    /// for some time.
    /// Generates and returns a ReadingEvent for this (ie. for HistoryManager)
    func reportContinuedReading() -> ReadingEvent? {
        return pdfReader!.getViewportStatus() as ReadingEvent?
    }
    
    /// Send the scientific document associated to the reader and updates the id stored by the reader with the value
    /// obtained from dime.
    func sendAndUpdateScidoc(_ sciDoc: ScientificDocument) {
        DiMePusher.sendToDiMe(sciDoc) {
            success, id in
            if success {
                self.pdfReader?.sciDoc?.id = id!
            }
        }
    }
    
    // MARK: - Metadata window
    
    @IBAction func thisDocMdata(_ sender: AnyObject?) {
        // create metadata window, if currently nil
        if metadataWindowController == nil {
            metadataWindowController = AppSingleton.mainStoryboard.instantiateController(withIdentifier: "MetadataWindow") as? MetadataWindowController
        }
        
        // show window controller for metadata and send data
        metadataWindowController?.showWindow(self)
        metadataWindowController?.setDoc(pdfReader!.document!, mainWC: self)
    }
    
    
    // MARK: - Saving
    
    func saveDocument(_ sender: AnyObject) {
        saveDocumentAs(sender)
    }
    
    func saveDocumentAs(_ sender: AnyObject) {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["pdf", "PDF"]
        panel.nameFieldStringValue = (document as? NSDocument)?.fileURL?.lastPathComponent ?? "Untitled"
        if panel.runModal() == NSFileHandlingPanelOKButton {
            pdfReader?.document!.write(to: panel.url!)
            let documentController = NSDocumentController.shared() 
            documentController.openDocument(withContentsOf: panel.url!, display: true) { _ in
                // empty, nothing else to do (NSDocumentController will automacally link URL to NSDocument (pdf file)
            }
        }
    }
    
    // MARK: - Initialization
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Toolbar button disabled at start (will be enabled once self.status changes)
        tbDocument.isEnabled = false
        // Toolbar buttons disabled at start (will be enabled in startTracking() if possible)
        self.tbTagButton.isEnabled = false
        self.tbTagItem.isEnabled = false
        
        // set size of window to 2/3 of screen size, if avaiable, otherwise use contants
        let oldFrame: NSRect
        if let screen = self.window?.screen {
            oldFrame = NSRect(origin: self.window!.frame.origin, size: NSSize(width: screen.visibleFrame.width / 3 * 2, height: screen.visibleFrame.height / 3 * 2))
        } else {
            oldFrame = NSRect(origin: self.window!.frame.origin, size: NSSize(width: PeyeConstants.docWindowWidth, height: PeyeConstants.docWindowHeight))
        }
        self.window!.setFrame(oldFrame, display: true)
        
        // Set reference to pdfReader for convenience by using references to children of this window
        let splV: NSSplitViewController = self.window?.contentViewController as! NSSplitViewController
        docSplitController = splV.childViewControllers[1] as? DocumentSplitController
        docSplitController?.sideCollapseDelegate = self
        pdfReader = docSplitController?.myPDFSideController?.pdfReader
        
        // Reference for click gesture recognizers
        readerDelegate = docSplitController?.myPDFSideController
        
        // Set reference to main split controller
        self.mainSplitController = self.contentViewController as? MainSplitController
        self.mainSplitController?.searchCollapseDelegate = self
        self.mainSplitController?.searchPanelController?.pdfReader = pdfReader
        
        pdfReader?.autoScales = true
        
        // Set annotate on or off depending on preference
        let enableAnnotate: Bool = UserDefaults.standard.object(forKey: PeyeConstants.prefEnableAnnotate) as! Bool
        setAnnotate(enableAnnotate)
        
        // Prepare to receive events
        setUpObservers()
    }
    
    /// Loads the PDF document and stores metadata inside it. Must be called after setting current document's URL.
    /// Sends a notification that the document has been loaded, with the document as object.
    func loadDocument() {
        // Load document and display it
        var pdfDoc: PDFDocument
        
        if let document: NSDocument = self.document as? NSDocument {
            let url: URL = document.fileURL!
            
            // set NSDocument subclass fields
            let peyeDoc = self.document as! PeyeDocument
            
            pdfDoc = PDFDocument(url: url)!
            peyeDoc.pdfDoc = pdfDoc
            pdfReader!.document = pdfDoc
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: PeyeConstants.documentChangeNotification, object: self.document)
            }
            
            // Tell app singleton which screen size we are using
            if let screen = window?.screen {
                AppSingleton.screenRect = screen.frame
            }
            
            // Asynchronously fetch text and other metadata from document
            processDocument()
            
            // Set flag indicating document loading is complete
            pdfReader!.documentLoaded = true
            
        }
        
    }
    
    /// Asynchronously fetched text in background from document and makes sure that it
    /// can be tracked. Call this immediately after load or when the document needs to be
    /// re-processed (e.g. the user wants to track it even if it was previously blocked).
    func processDocument() {
        // disable document toolbar button before starting
        DispatchQueue.main.async {
            self.tbDocument.isEnabled = false
        }
        pdfReader?.checkPlainText() {
            [weak self] result in
            self?.checkMetadata(result)
        }
    }
    
    /// Asynchronously fetch metadata (including plain text) from PDF.
    /// Try to find the document which matches extracted data in DiMe.
    fileprivate func checkMetadata(_ plainText: String?) {
        guard let pdfr = self.pdfReader, let _ = self.document else {
            return
        }
        
        // Associate PDF view to info element
        let url = (self.document as! PeyeDocument).fileURL!
        guard let pdfDoc = pdfr.document else {
            return
        }
        let sciDoc: ScientificDocument
        if let txt = plainText,
            let _sciDoc = DiMeFetcher.getScientificDocument(for: SciDocConvertible.contentHash(txt.sha1())) {
            // if found, associate object and update uri
            sciDoc = _sciDoc
            sciDoc.uri = url.path
        } else {
            sciDoc = ScientificDocument(uri: url.path, plainTextContent: plainText, title: pdfDoc.getTitle(), authors: pdfDoc.getAuthorsAsArray(), keywords: pdfDoc.getKeywordsAsArray(), subject: pdfDoc.getSubject())
        }
        
        pdfr.sciDoc = sciDoc
        
        // at the very end, check if there's text andupdate status
        if let foundText = plainText {
            // changing status will start tracking, if new status is trackable
            let blockedStrings = UserDefaults.standard.object(forKey: PeyeConstants.prefStringBlockList) as! [String]
            if foundText.containsAny(strings: blockedStrings) {
                pdfr.status = .blocked
            } else {
                pdfr.status = .trackable
            }
        } else {
            pdfr.status = .impossible
        }

    }
    
    
    /// Prepares all the notification centre observers + timers (will have to be removed when the window wants to close). See unSetObservers, these two methods should load / unload the same observers.
    fileprivate func setUpObservers() {
        
        // Get notifications from pdfview for window
        
        NotificationCenter.default.addObserver(self, selector: #selector(autoAnnotateComplete(_:)), name: PeyeConstants.autoAnnotationComplete, object: self.pdfReader!)
        NotificationCenter.default.addObserver(self, selector: #selector(zoomChanged(_:)), name: NSNotification.Name.PDFViewScaleChanged, object: self.pdfReader!)
        NotificationCenter.default.addObserver(self, selector: #selector(frameChanged(_:)), name: NSNotification.Name.NSViewFrameDidChange, object: self.pdfReader!)
        // Note: forced downcast below relies on "undocumented" view tree
        NotificationCenter.default.addObserver(self, selector: #selector(scrollingChanged(_:)), name: NSNotification.Name.NSViewBoundsDidChange, object: self.pdfReader!.subviews[0].subviews[0] as! NSClipView)
        
        // Get notifications from managed window
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowMoved(_:)), name: NSNotification.Name.NSWindowDidMove, object: self.window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillSwitchAway(_:)), name: NSNotification.Name.NSWindowDidResignKey, object: self.window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowWantsMain(_:)), name: NSNotification.Name.NSWindowDidBecomeKey, object: self.window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowOcclusionChange(_:)), name: NSNotification.Name.NSWindowDidChangeOcclusionState, object: self.window)
        
        // Get notifications about user's eyes (present or not)
        
        NotificationCenter.default.addObserver(self, selector: #selector(eyeStateCallback(_:)), name: PeyeConstants.eyesAvailabilityNotification, object: nil)
        
        // Get notification from DiMe connection status
        
        NotificationCenter.default.addObserver(self, selector: #selector(dimeConnectionChanged(_:)), name: PeyeConstants.diMeConnectionNotification, object: nil)
        
        // Get redo notifications to be sent to peers
        NotificationCenter.default.addObserver(self, selector: #selector(didRedo(_:)), name: Notification.Name.NSUndoManagerDidRedoChange, object: self.pdfReader!.undoManager!)
        
        // Set up regular timer
        DocumentWindowController.timerQueue.sync {
            if self.regularTimer == nil {
                self.regularTimer = Timer(timeInterval: PeyeConstants.regularSummaryEventInterval, target: self, selector: #selector(self.regularTimerFire(_:)), userInfo: nil, repeats: true)
                RunLoop.current.add(self.regularTimer!, forMode: RunLoopMode.commonModes)
            }
        }
    }
    
    // MARK: - Timer callbacks
    
    /// The regular timer is a repeating timer that regularly submits a summary event to dime
    @objc fileprivate func regularTimerFire(_ regularTimer: Timer) {
        guard let pdfr = pdfReader, pdfr.status == .trackable else {
            return
        }
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            if self.totalReadingTime >= PeyeConstants.minTotalReadTime {
                // update id of summary event
                let summaryEv = pdfr.makeSummaryEvent()
                summaryEv.readingTime = self.totalReadingTime
                DiMePusher.sendToDiMe(summaryEv) {
                    _, id in
                    pdfr.setSummaryId(id)
                }
                
                // update tags
                if let own_sciDoc = self.pdfReader!.sciDoc, let cHash = own_sciDoc.contentHash, let dime_sciDoc = DiMeFetcher.getScientificDocument(for: SciDocConvertible.contentHash(cHash)) {
                    self.pdfReader!.sciDoc!.id = dime_sciDoc.id!
                    self.pdfReader!.sciDoc!.updateTags()
                }
            }
        }
    }
    
    // MARK: - Unloading
    
    /// This window is going to close, send exit event and send all paragraph data to HistoryManager as summary. Calls the given callback once done saving to dime.
    func unload(_ callback: ((Void) -> Void)? = nil) {
        guard closeToken == 0 else {
            return
        }
        closeToken += 1
        stoppedReading()
        self.unSetObservers()
        self.metadataWindowController?.close()
        
        // tell multipeer to forget about this window
        if let cHash = pdfReader?.sciDoc?.contentHash {
            Multipeer.ourWindows.removeValue(forKey: cHash)
        }
        // tell other peers that we are now idle
        CollaborationMessage.reportIdle.sendToAll()
        
        guard let pdfr = self.pdfReader else {
            callback?()
            return
        }
        
        // If the document can be tracked anddime is available, call the callback after the dime operation is done,
        // otherwise call the callback right now
        if pdfr.status == .trackable && DiMeSession.dimeAvailable {
            let ww = NSWindow()
            let wvc = AppSingleton.mainStoryboard.instantiateController(withIdentifier: "WaitVC") as! WaitViewController
            ww.contentViewController = wvc
            wvc.someText = "Sending data to DiMe..."
            self.window!.beginSheet(ww, completionHandler: nil)
            // send data to dime (if document has been edited -- annotations have been added -- or enough
            // time elapsed)
            if let doc = self.document as? PeyeDocument,
                (doc.wereAnnotationsAdded || self.totalReadingTime >= PeyeConstants.minTotalReadTime) {
                let summaryEv = pdfr.makeSummaryEvent()
                summaryEv.readingTime = self.totalReadingTime
                DiMePusher.sendToDiMe(summaryEv) {
                    _ in
                    // signal when done
                    DispatchQueue.main.async {
                        self.pdfReader!.document = nil
                        self.pdfReader!.markings = nil
                        self.window!.endSheet(ww)
                        callback?()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.pdfReader!.document = nil
                    self.pdfReader!.markings = nil
                    self.window!.endSheet(ww)
                    callback?()
                }
            }
        } else {
            DispatchQueue.main.async {
                self.pdfReader!.document = nil
                self.pdfReader!.markings = nil
                callback?()
            }
        }
    }
    
    /// Removes all the observers created in setUpObservers()
    fileprivate func unSetObservers() {
        
        // Notifications unloading is no longer required (observers deallocate automatically)
        
        // Stop regular timer
        if let timer = regularTimer {
            DocumentWindowController.timerQueue.sync {
                    timer.invalidate()
            }
            regularTimer = nil
        }
    }
    
    // MARK: - Notification callbacks from managed pdf view
    
    @objc fileprivate func zoomChanged(_ notification: Notification) {
        startedReading()
        if pdfReader?.drawDebugCirle ?? false {
            readerDelegate?.clearFixations()
        }
    }
    
    @objc fileprivate func frameChanged(_ notification: Notification) {
        startedReading()
        if pdfReader?.drawDebugCirle ?? false {
            readerDelegate?.clearFixations()
        }
    }
    
    @objc fileprivate func scrollingChanged(_ notification: Notification) {
        startedReading()
        if pdfReader?.drawDebugCirle ?? false {
            readerDelegate?.clearFixations()
        }
    }
    
    // MARK: - Notification callbacks from window
    
    @objc fileprivate func didRedo(_ notification: Notification) {
        // if someone is tracking us, tell them to redo
        if Multipeer.trackers.count > 0 {
            CollaborationMessage.redo.sendTo(Multipeer.trackers.map({$0}))
        }
    }
    
    @objc fileprivate func windowMoved(_ notification: Notification) {
        startedReading()
    }
    
    /// Enables the annotate toolbar button when auto annotation is complete
    @objc fileprivate func autoAnnotateComplete(_ notification: Notification) {
        tbAnnotate.isEnabled = true
    }
    
    /// This method is called when the managed window wants to become main window
    @objc fileprivate func windowWantsMain(_ notification: Notification) {
        // do not do anything if the window is closing
        guard closeToken == 0 else {
            return
        }
        
        NotificationCenter.default.post(name: PeyeConstants.documentChangeNotification, object: self.document)
        
        // Set up regular timer
        DocumentWindowController.timerQueue.sync {
            if self.regularTimer == nil {
                self.regularTimer = Timer(timeInterval: PeyeConstants.regularSummaryEventInterval, target: self, selector: #selector(self.regularTimerFire(_:)), userInfo: nil, repeats: true)
                RunLoop.current.add(self.regularTimer!, forMode: RunLoopMode.commonModes)
            }
        }
        
        // If the relevant preference is set, send a DesktopEvent for the current document
        if (UserDefaults.standard.object(forKey: PeyeConstants.prefSendEventOnFocusSwitch) as! Bool) {
            sendDeskEvent()
        } else if let sciDoc = self.pdfReader?.sciDoc {
            // otherwise just send an information element for the given document if the current document
            // does not have already an associated info elemen in dime
            let showTime = DispatchTime.now() + 2  // two-second wait
            DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).asyncAfter(deadline: showTime) {
                [weak self] in
                DiMeFetcher.retrieveScientificDocument(sciDoc.appId) {
                    scidoc in
                    if scidoc == nil {
                        self?.sendAndUpdateScidoc(sciDoc)
                    }
                }
            }
        }
        
        // Tell peers we started reading this document
        
        startedReading()
    }
    
    /// Unused yet (probably not really needed as we already know when windowWillSwitchAway)
    @objc fileprivate func windowOcclusionChange(_ notification: Notification) {
        NotificationCenter.default.post(name: PeyeConstants.occlusionChangeNotification, object: self.window)
    }
    
    /// The managed window will stop being key window
    @objc fileprivate func windowWillSwitchAway(_ notification: Notification) {
        stoppedReading()
        
        // Stop regular timer
        if let timer = regularTimer {
            DocumentWindowController.timerQueue.sync {
                    timer.invalidate()
            }
            regularTimer = nil
        }
    }
   
    // MARK: - Window delegate
    
    /// Ensures that the document window never gets bigger than the maximum
    /// allowed size when eye tracker is active and stays within its boundaries.
    func windowDidResize(_ notification: Notification) {
        // only constrain if eye tracker is active and relevant preference is on
        if (AppSingleton.eyeTracker?.available ?? false) && AppSingleton.constrainMaxWindowSize {
            if let window = notification.object as? NSWindow, let screen = window.screen {
                let shrankRect = DocumentWindow.getConstrainingRect(forScreen: screen)
                let intersectedRect = shrankRect.intersection(window.frame)
                if intersectedRect != window.frame {
                    window.setFrame(intersectedRect, display: true)
                }
            }
        }
    }
    
    // MARK: - Notification callbacks
    
    /// Reacts to eye being lost / found. If status changes when this is
    /// key window, send exit / enter event as necessary
    @objc fileprivate func eyeStateCallback(_ notification: Notification) {
        if self.window!.isKeyWindow {
            let uInfo = (notification as NSNotification).userInfo as! [String: AnyObject]
            let avail = uInfo["available"] as! Bool
            if avail {
                startedReading()
            } else {
                stoppedReading()
            }
        }
    }
    
    /// Enable functions related to dime (e.g. tags) and refreshes scidoc when dime comes online
    @objc fileprivate func dimeConnectionChanged(_ notification: Notification) {
        guard let pdfr = self.pdfReader else {
            AppSingleton.log.error("Could not reference a valid pdfReader object")
            return
        }
        let userInfo = (notification as NSNotification).userInfo as! [String: Bool]
        let dimeAvailable = userInfo["available"]!
        
        DispatchQueue.main.async {
            self.tbTagButton.isEnabled = dimeAvailable && pdfr.status == .trackable
            self.tbTagItem.isEnabled = dimeAvailable && pdfr.status == .trackable
        }
        
        // update data from dime after a small random delay
        if dimeAvailable {
            let randWait = 1 + drand48() * 0.5  // random amount between 1 and 1.5
            let showTime = DispatchTime.now() + Double(Int64(randWait * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).asyncAfter(deadline: showTime) {
                if let own_sciDoc = pdfr.sciDoc, let cHash = own_sciDoc.contentHash, let dime_sciDoc = DiMeFetcher.getScientificDocument(for: SciDocConvertible.contentHash(cHash)) {
                    pdfr.sciDoc!.id = dime_sciDoc.id!
                    pdfr.sciDoc!.updateTags()
                }
            }
        }
    }
}

enum TagOperation {
    case none  // we are not tagging
    case document  // tagging the document as a whole
    case manualSelection(PDFSelection)  // tagging a manual selection
    case previousReading([ReadingTag])  // tagging previously existing reading tags (user clicked on them)
}

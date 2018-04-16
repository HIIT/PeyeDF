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

import Foundation
import Cocoa
import Quartz
import os.log

/// Status of a pdfReader instance
enum TrackingStatus: CustomStringConvertible {
    /// Yet to be processed
    case unknown
    /// Tracking is allowed
    case trackable
    /// Tracking was blocked (e.g. document contains sensitive info)
    case blocked
    /// Tracking is not supported (e.g. document does not contain text info)
    case impossible
    
    /// An image which can be used to represent this status to the user
    var image: NSImage { get {
        switch self {
        case .unknown:
            return NSImage(named: NSImage.Name.statusNone)!
        case .trackable:
            return NSImage(named: NSImage.Name.statusAvailable)!
        case .blocked:
            return NSImage(named: NSImage.Name.statusPartiallyAvailable)!
        case .impossible:
            return NSImage(named: NSImage.Name.statusUnavailable)!
        }
    } }
    
    /// A description of the status for the user
    var description: String { get {
        switch self {
        case .blocked:
            return "Tracking was blocked"
        case .impossible:
            return "Tracking is not possible for this document"
        case .trackable:
            return "Tracking is enabled"
        case .unknown:
            return "Status unknown"
        }
    } }
}

/// Implementation of a custom PDFView class, used to provide additional functions related to
/// psychophysiology and user activity tracking
class PDFReader: PDFBase {
    
    /// Whether we want to annotate by clicking
    fileprivate var clickAnnotationEnabled = true
    
    /// Whether we want to draw debug circle
    lazy var drawDebugCirle: Bool = {
        return UserDefaults.standard.object(forKey: PeyeConstants.prefDrawDebugCircle) as! Bool
    }()
    
    /// Queue on which status updates are stored / read, to avoid data races
    private static let statusQueue = DispatchQueue(label: "hiit.PeyeDF.PDFReader.statusQueue", qos: .userInitiated)
    
    /// Whether history tracking can be done on this document
    /// Changing this automatically sets the toolbar image and
    /// enables the toolbar item (if the status is anything other than unknown).
    /// If we go to the trackable status, tells the window controller to start tracking
    var status: TrackingStatus { get {
            return PDFReader.statusQueue.sync {
                return self.privateStatus
            }
        }
        set {
            PDFReader.statusQueue.sync {
                self.privateStatus = newValue
            }
    } }
    
    /// Private representation of status, should not be accessed directly (modify the "normal"
    /// representation of status instead, which uses a serial queue)
    private var privateStatus: TrackingStatus = .unknown { didSet {
        DispatchQueue.main.async {
            [unowned self] in
            guard let dwc = self.window?.windowController as? DocumentWindowController else {
                return
            }
            
            dwc.tbDocument.isEnabled = !(self.status == .unknown)
            dwc.tbDocument.image = self.status.image
            
            if (oldValue == .blocked || oldValue == .unknown) && self.status == .trackable {
                dwc.startTracking()
            }
        }
    } }
    
    /// Id for this reading session, all events sent by this instance should have the same value
    let sessionId: String = { return UUID().uuidString.sha1() }()
    
    /// We set this if we have a reference to a preceding reading session
    /// (we re-started reading).
    /// Will be sent to all reading events and summary reading events
    var previousSessionId: String?
    
    /// Id for the outgoing summary event. If set, forces dime to replace the event with this id
    /// (useful to regularly update the outgoing summary event)
    fileprivate(set) var summaryId: Int?
    
    /// Stores all strings searched for and found by user
    fileprivate lazy var foundStrings = { return [String]() }()
    
    /// Stores the information element for the current document.
    /// Set by DocumentWindowController.loadDocument()
    var sciDoc: ScientificDocument? { didSet {
        
        if let sd = sciDoc {
            // pdf reader gets notification from info elem tag changes
            NotificationCenter.default.addObserver(self, selector: #selector(tagsChanged(_:)), name: NSNotification.Name(rawValue: TagConstants.tagsChangedNotification), object: sd)
            
            readingTags = sd.tags.compactMap({$0 as? ReadingTag})
        }
        
    } }
    
    /// Delegate for clicks gesture recognizer
    var readerDelegate: PDFReaderDelegate?
    
    // MARK: - Right click menu
    
    /// Overridden menu to allow extra actions such as tagging
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event)
        
        menu?.insertItem(NSMenuItem.separator(), at: 0)
        
        let markAsCriticalMenuItem = NSMenuItem(title: "Mark as Critical", action: #selector(selectionMark), keyEquivalent: "2")
        markAsCriticalMenuItem.tag = ReadingClass.high.rawValue
        menu?.insertItem(markAsCriticalMenuItem, at: 0)
        
        let markAsImportantMenuItem = NSMenuItem(title: "Mark as Important", action: #selector(selectionMark), keyEquivalent: "1")
        markAsImportantMenuItem.tag = ReadingClass.medium.rawValue
        menu?.insertItem(markAsImportantMenuItem, at: 0)
        
        let docwin = self.window!.windowController! as! DocumentWindowController
        let tagMenuItem = NSMenuItem(title: "Tag", action: #selector(docwin.tagShow(_:)), keyEquivalent: "t")
        tagMenuItem.tag = Int(TagConstants.tagMenuTag)
        menu?.insertItem(NSMenuItem.separator(), at: 0)
        menu?.insertItem(tagMenuItem, at: 0)

        return menu
    }
    
    // MARK: - Debugging-related fields
    
    /// Position of the circle
    var circlePosition: NSPoint?
    
    /// Size of circle
    var circleSize = NSSize(width: 20, height: 20)
    
    // MARK: - Event callbacks
    
    /// To receive single click actions (select tag corresponding to text)
    override func mouseUp(with theEvent: NSEvent) {
        
        if status == .trackable && theEvent.clickCount == 1 && !mouseDragging {
            /// GETTING MOUSE LOCATION IN WINDOW FROM SCREEN COORDINATES (for debug reasons)
            // get mouse in screen coordinates
            let mouseLoc = NSEvent.mouseLocation
            for screen in NSScreen.screens {
                if NSMouseInRect(mouseLoc, screen.frame, false) {
                    let tinySize = NSSize(width: 1, height: 1)
                    let mouseRect = NSRect(origin: mouseLoc, size: tinySize)
                    //let rawLocation = screen.convertRectToBacking(mouseRect)
                    
                    // use raw location to map back into view coordinates
                    let mouseInWindow = self.window!.convertFromScreen(mouseRect)
                    let mouseInView = self.convert(mouseInWindow, from: self.window!.contentViewController!.view)
                    
                    // if there are no tags here, propagate event
                    if !showTags(mouseInView.origin) {
                        super.mouseUp(with: theEvent)
                        
                        // MF: TODO: remove this once debugging is complete
                        #if DEBUG
                        if AppSingleton.eyeTracker == nil {
                            // send rect
                            let activePage = self.page(for: mouseInView.origin, nearest: true)
                            let pointOnPage = self.convert(mouseInView.origin, to: activePage!)
                            if let rect = pointToParagraphRect(pointOnPage, forPage: activePage!),
                               let doc = self.document {
                                let area = FocusArea(forRect: rect, onPage: doc.index(for: activePage!))
                                if let cHash = sciDoc?.contentHash {
                                    Multipeer.overviewControllers[cHash]?.pdfOverview.addArea(area, fromSource: .localPeer)
                                }
                                CollaborationMessage.seenAreas([area]).sendToAll()
                            } else if let triple = screenToPage(mouseRect.origin, fromEye: false) {
                                // send circle
                                let diameter = pointSpan(zoomLevel: scaleFactor, dpi: AppSingleton.getComputedDPI()!, distancemm: AppSingleton.eyeTracker?.lastValidDistance ?? 800)
                                let circle = Circle(x: CGFloat(triple.x), y: CGFloat(triple.y), r: diameter / 4)
                                let area = FocusArea(forCircle: circle, onPage: triple.pageIndex)
                                
                                // send found area to peers
                                if Multipeer.session.connectedPeers.count > 0,
                                    let cHash = sciDoc?.contentHash {
                                    CollaborationMessage.seenAreas([area]).sendToAll()
                                    Multipeer.overviewControllers[cHash]?.pdfOverview?.addArea(area, fromSource: .localPeer)
                                }
                            }
                        }
                        #endif
                    }
                }
            }
        }
        
    }
    
    /// SciDoc tags changed
    @objc func tagsChanged(_ notification: Notification) {
        if let uInfo = (notification as NSNotification).userInfo, let newTags = uInfo["tags"] as? [Tag] {
            readingTags = newTags.compactMap({$0 as? ReadingTag})
        }
    }
    
    // MARK: - Received actions
    
    /// Looks up a found selection, used when a user selects a search result
    func foundResult(_ selectedResult: PDFSelection) {
        DispatchQueue.main.async {
            self.setCurrentSelection(selectedResult, animate: false)
            self.scrollSelectionToVisible(self)
            self.setCurrentSelection(selectedResult, animate: true)
        }
        let foundString = selectedResult.string!.lowercased()
        if foundStrings.index(of: foundString) == nil {
            foundStrings.append(foundString)
        }
        let foundOnPage = selectedResult.pages[0] 
        let pageIndex = document!.index(for: foundOnPage)
        let newRect = ReadingRect(pageIndex: pageIndex, rect: selectedResult.bounds(for: foundOnPage), readingClass: .foundString, classSource: .search, pdfBase: self)
        markings.addRect(newRect)
        HistoryManager.sharedManager.addReadingRect(newRect)
    }
        
    // MARK: - Markings and Annotations
    
    /// Marks the given selection with a predefined importance
    @IBAction func selectionMark(sender: AnyObject?) {
        
        guard let sender = sender, let importance = ReadingClass(rawValue: sender.tag) else {
            if #available(OSX 10.12, *) {
                os_log("Failed to convert sender's tag to an importance", type: .error)
            }
            return
        }
        
        if importance != ReadingClass.low && importance != ReadingClass.medium && importance != ReadingClass.high {
            let exception = NSException(name: NSExceptionName(rawValue: "Not implemented"), reason: "Unsupported reading class for annotation", userInfo: nil)
            exception.raise()
        }
        
        if let markRects = ReadingRect.makeReadingRects(fromSelectionIn: self, importance: importance) {
            selectionMarkAndAnnotate(markRects)
        }
    }
    
    /// This method is called (so far) only by the undo manager.
    /// It sets the state of markings to the specified object (markingState) and
    /// refreshes the view (so that the change can be seen appearing / disappearing immediately).
    @objc func undoMarkAndAnnotate(_ previousState: PDFMarkingsState) {
        // if someone is tracking us, tell them to undo
        if Multipeer.trackers.count > 0 {
            if !(undoManager?.isRedoing ?? false) {
                CollaborationMessage.undo.sendTo(Multipeer.trackers.map({$0}))
            }
        }
        
        // store previous state before making any modification
        let evenPreviousState = PDFMarkingsState(oldState: markings.getAll(forSources: [.click, .manualSelection]))
        
        // apply previous state and perform annotations
        markings.setAll(forSources: [.click, .manualSelection], newRects: previousState.rectState)
        autoAnnotate()
    
        // if we have a last rect, refresh the view only for the area covered by it.
        // if last rect is nil (this was a big change) refresh whole document.
        if previousState.lastRects.count > 0 {
            // refresh the view for all rects affected by the undo
            previousState.lastRects.forEach() {
                rRect in
            }
            // save last modified rects in state for redo
            evenPreviousState.lastRects = previousState.lastRects
        } else {
            DispatchQueue.main.async {
                self.layoutDocumentView()
                self.display()
            }
        }
        
        // create an undo operation for this operation
        undoManager?.registerUndo(withTarget: self, selector: #selector(undoMarkAndAnnotate(_:)), object: evenPreviousState)
        undoManager?.setActionName(NSLocalizedString("actions.annotate", value: "Mark Text", comment: "Some text was marked via clicking / undoing"))
    }
    
    /// Create a marking (and subsequently a rect) at the given point, and make annotations.
    /// Sends a notification that a marking was done.
    ///
    /// - parameter location: The point for which a rect will be created (in view coordinates)
    /// - parameter importance: The importance of the rect that will be created
    func quickMarkAndAnnotate(_ location: NSPoint, importance: ReadingClass) {
        guard status == .trackable else {
            return
        }

        // prepare a marking state to store this operation
        let previousState = PDFMarkingsState(oldState: self.markings.getAll(forSources: [.click, .manualSelection]))
        
        let newMark = ReadingRect(fromPoint: location, pdfBase: self, importance: importance)
        
        // if noting was done (i.e. no paragraph at point) do nothing, otherwise store state and annotate
        guard let markRect = newMark else {
            return
        }
        
        previousState.lastRects = [markRect]
        undoManager?.registerUndo(withTarget: self, selector: #selector(undoMarkAndAnnotate(_:)), object: previousState)
        undoManager?.setActionName(NSLocalizedString("actions.annotate", value: "Quick Mark Text", comment: "Some text was marked via clicking / undoing"))
        
        markings.addRect(markRect)
        HistoryManager.sharedManager.addReadingRect(markRect)
        autoAnnotate()
        
        let unixtimeDict = ["unixtime": Date().unixTime]
        NotificationCenter.default.post(name: PeyeConstants.manualParagraphMarkNotification, object: self, userInfo: unixtimeDict)
    }
    
    /// Create a set of markings for the current selection (which can span multiple lines).
    /// Sends a notification that the marking was done.
    /// Does not do anything if nothing is currently selected.
    func selectionMarkAndAnnotate(_ markRects: [ReadingRect]) {
        guard status == .trackable else {
            return
        }
        
        guard markRects.count > 0 else {
            return
        }
        
        // if there's someone tracking us, send them the markings
        if Multipeer.trackers.count > 0 {
            let message = CollaborationMessage.markRects(markRects)
            message.sendTo(Multipeer.trackers.map({$0}))
        }
        
        // prepare a marking state to store this operation
        let previousState = PDFMarkingsState(oldState: self.markings.getAll(forSources: [.click, .manualSelection]))
        
        previousState.lastRects = markRects
        undoManager?.registerUndo(withTarget: self, selector: #selector(undoMarkAndAnnotate(_:)), object: previousState)
        undoManager?.setActionName(NSLocalizedString("actions.annotate", value: "Selection Mark Text", comment: "Some text was marked via clicking / undoing"))
        
        markRects.forEach({
            markings.addRect($0)
            HistoryManager.sharedManager.addReadingRect($0)
        })
        autoAnnotate()

        let unixtimeDict = ["unixtime": Date().unixTime]
        NotificationCenter.default.post(name: PeyeConstants.manualParagraphMarkNotification, object: self, userInfo: unixtimeDict)
    }

    
    /// Given a set of markings, apply them all at once as click markings and create
    /// and undo operation so that the previous state can be restored.
    /// For now forces and converts all given rects' source to manual (i.e. click markings).
    /// - Note: Only rects with classSource .Click will be added
    func markAndAnnotateBulk(_ newMarks: [ReadingRect]) {
        let previousState = PDFMarkingsState(oldState: self.markings.getAll(forSource: .click))
        undoManager?.registerUndo(withTarget: self, selector: #selector(undoMarkAndAnnotate(_:)), object: previousState)
        undoManager?.setActionName(NSLocalizedString("actions.annotate", value: "Bulk Annotate", comment: "Many annotations were changed in bulk"))
        
        self.markings.setAll(forSources: [.click, .manualSelection], newRects: newMarks)
        autoAnnotate()
    }

    /// Returns wheter annotation by click is enabled
    func clickAnnotationIsEnabled() -> Bool {
        return self.clickAnnotationEnabled
    }
    
    /// Enabled / disables auto annotation by click
    func setClickAnnotationTo(_ enabled: Bool) {
        self.clickAnnotationEnabled = enabled
        self.readerDelegate?.setRecognizersTo(enabled)
    }
    
    // MARK: - Setters
    
    /// Sets the outgoing summary event id to the given value (to update previously sent summary event).
    /// If nil, this won't be used (a new summary event will be sent next time).
    func setSummaryId(_ newId: Int?) {
        summaryId = newId
    }
    
    // MARK: - General accessor methods
    
    /// Converts a point on screen and returns a triple containing x coordinate, y coordinate (both in page space) and page index. Should be called for each fixation retrieved during the current event.
    ///
    /// - parameter pointOnScreen: point to convert (in OS X coordinate system)
    /// - parameter fromEye: if this is being done because of eye tracking (so gaze points are stored)
    /// - returns: A triple containing x, y in page coordinates, and the index of the page in which gaze fell
    func screenToPage(_ pointOnScreen: NSPoint, fromEye: Bool) -> (x: Double, y: Double, pageIndex: Int)? {
        guard let document = self.document else { return nil }
        
        let tinySize = NSSize(width: 1, height: 1)
        let tinyRect = NSRect(origin: pointOnScreen, size: tinySize)
        
        let rectInWindow = self.window!.convertFromScreen(tinyRect)
        let rectInView = self.convert(rectInWindow, from: self.window!.contentViewController!.view)
        let pointInView = rectInView.origin
        
        //  return nil if the point is outside this view
        if pointInView.x < 0 || pointInView.y < 0 || pointInView.x > frame.width || pointInView.y > frame.height {
            return nil
        }
        // otherwise calculate point on page, but return nil if point is out of page
        let page = self.page(for: pointInView, nearest:false)
        if page == nil {
            return nil
        }
        let pointOnPage = self.convert(pointInView, to: page!)
        
        let pageIndex = document.index(for: page!)
        
        // create rect for gazed-at paragraph. Note: this will store rects that will later be sent
        // in a summary event. This is different from eye rectangles created by each fixation and
        // sent in the current (non-summary) reading event, as done by HistoryManager calling getSMIRect
        // (preferred method to fetch eye tracking data).
        if fromEye {
            if let seenRect = pointToParagraphRect(pointOnPage, forPage: page!) {
                
                let pageIndex = document.index(for: page!)
                
                let newRect = ReadingRect(pageIndex: pageIndex, rect: seenRect, readingClass: .paragraph, classSource: .smi, pdfBase: self)
                markings.addRect(newRect)
                
            }
            
            // draw our circle if needed
            if drawDebugCirle {
                NotificationCenter.default.post(name: PeyeConstants.fixationWithinDocNotification, object: self, userInfo: ["xpos": pointInView.x, "ypos": pointInView.y])
            }

            // if we are being tracked, send fixation to peer(s)
            if Multipeer.trackers.count > 0 {
                let message = CollaborationMessage.fixation(FocusArea(forPoint: pointOnPage, onPage: pageIndex))
                message.sendTo(Multipeer.trackers.map({$0}))
            }
        }
        
        return (x: Double(pointOnPage.x), y: Double(pointOnPage.y), pageIndex: pageIndex)
    }
    
    /// Creates a reading rect using the triple returned from screenToPage, corresponding to the paragraph contained within 3 degrees of visual angle of the given fixation. As of PeyeDF 0.4+, this is the preferred method to send reading rects to dime.
    func getReadingRect(_ triple: (x: Double, y: Double, pageIndex: Int)) -> ReadingRect? {
        let pointOnPage = NSPoint(x: triple.x, y: triple.y)
        let pdfPage = document!.page(at: triple.pageIndex)
        if let sr = pointToParagraphRect(pointOnPage, forPage: pdfPage!) {
            return ReadingRect(pageIndex: triple.pageIndex, rect: sr, readingClass: .paragraph, classSource: .smi, pdfBase: self)
        } else {
            return nil
        }
    }
    
    /// Gets the current scaleFactor (zoom level)
    func getScaleFactor() -> CGFloat {
        return scaleFactor
    }
    
    /// Converts the current viewport to a reading event.
    /// Adds the current viewport to our markings.
    ///
    /// - returns: The reading event for the current status, or nil if nothing is actually visible
    func getViewportStatus() -> ReadingEvent? {
        guard self.status == .trackable else {
            return nil
        }
        
        let visiblePageLabels: [String] = getVisiblePageLabels()
        let visiblePageNums: [Int] = getVisiblePageNums()
        let pageRects: [NSRect] = getVisibleRects()
        var plainTextContent = ""
        
        if let textContent = getVisibleString() {
            plainTextContent = textContent
        }
        
        var readingRects = [ReadingRect]()
        var vpi = 0
        for rect in pageRects {
            let visiblePageNum = visiblePageNums[vpi]
            let newRect = ReadingRect(pageIndex: visiblePageNum, rect: rect, readingClass: ReadingClass.viewport, classSource: ClassSource.viewport, pdfBase: self)
            readingRects.append(newRect)
            markings.addRect(newRect) // keep track of seen viewports
            vpi += 1
        }
        
        let outgoingEvent = ReadingEvent(sessionId: sessionId, pageNumbers: visiblePageNums, pageLabels: visiblePageLabels, pageRects: readingRects, plainTextContent: plainTextContent, infoElemId: sciDoc!.getAppId())
        outgoingEvent.previousSessionId = previousSessionId
        return outgoingEvent
    }
    
    /// Returns all rectangles with their corresponding class, marked by the user (and basic eye tracking)
    ///
    /// - returns: A summary reading event containing to all marks
    func makeSummaryEvent() -> SummaryReadingEvent {
        
        guard status == .trackable else {
            fatalError("Attempted to generate a summary of a non-trackable pdf")
        }
        
        // only include new readingrects in outgoing summary
        let outgoingRects = markings.getAllReadingRects().filter({$0.new})
        
        let retEv = SummaryReadingEvent(rects: outgoingRects, sessionId: sessionId, plainTextContent: nil, infoElemId: sciDoc!.getAppId(), foundStrings: foundStrings)
        retEv.previousSessionId = previousSessionId
        if let id = summaryId {
            retEv.setId(id)
        }
        
        // Calculate proportion for Read, Critical and Interesting rectangles
        let prop = markings.calculateProportions_relevance(onlyNew: true)!
        let proportionSeen = markings.calculateProportion_seen()
        
        retEv.setProportions(proportionSeen, prop.proportionRead, prop.proportionInteresting, prop.proportionCritical)
        return retEv
    }
    
    /// Get the rectangle of the pdf view, in screen coordinates
    func getRectOfViewOnScreen() -> NSRect {
        // get a rectangle representing the pdfview frame, relative to its superview and convert to the window's view
        let r1:NSRect = self.superview!.convert(self.frame, to: self.window!.contentView!)
        // get screen coordinates corresponding to the rectangle got in the previous line
        let r2 = self.window!.convertToScreen(r1)
        return r2
    }
    
    /// Check if page labels and page numbers are the same for the current document
    func pageNumbersSameAsLabels() -> Bool {
        for i in 0..<document!.pageCount {
            let page = document!.page(at: i)
            if page!.label != "\(i+1)" {
                return false
            }
        }
        return true
    }
    
    /// Returns the visible text as a string, or nil if no text can be fetched.
    func getVisibleString() -> String? {
        // Only proceed if there is actually text to select
        guard status == .trackable else {
            return nil
        }
        let visiblePages = self.visiblePages
        guard let document = self.document else {
            return nil
        }
        let generatedSelection = PDFSelection(document: document)
        
        for visiblePage in visiblePages {
            
            // Get page's rectangle coordinates
            let pageRect = getPageRect(visiblePage)
            
            // Get viewport rect and apply margin
            var visibleRect = NSRect(origin: CGPoint(x: 0, y: 0), size: self.frame.size)
            visibleRect = visibleRect.insetBy(dx: PeyeConstants.extraMargin, dy: PeyeConstants.extraMargin)
            
            visibleRect = self.convert(visibleRect, to: visiblePage)  // Convert rect to page coordinates
            visibleRect = visibleRect.intersection(pageRect)  // Intersect to get seen portion
            
            if let sel = visiblePage.selection(for: visibleRect) {
                generatedSelection.add(sel)
            }
        }
        
        return generatedSelection.string
    }
   
    // MARK: - Debug functions
    
    /// Debug function to test "seen text"
    func selectVisibleText(_ sender: AnyObject?) {
        guard status == .trackable, let document = self.document else {
            return
        }
        
        let visiblePages = self.visiblePages
 
        let generatedSelection = PDFSelection(document: document)
        
        for visiblePage in visiblePages {
            
            // Get page's rectangle coordinates
            let pageRect = getPageRect(visiblePage)
            
            // Get viewport rect and apply margin
            var visibleRect = NSRect(origin: CGPoint(x: 0, y: 0), size: self.frame.size)
            visibleRect = visibleRect.insetBy(dx: PeyeConstants.extraMargin, dy: PeyeConstants.extraMargin)
            
            visibleRect = self.convert(visibleRect, to: visiblePage)  // Convert rect to page coordinates
            visibleRect = visibleRect.intersection(pageRect)  // Intersect to get seen portion
            
            if let sel = visiblePage.selection(for: visibleRect) {
                generatedSelection.add(sel)
            }
        }
        
        self.setCurrentSelection(generatedSelection, animate: true)
    }
}

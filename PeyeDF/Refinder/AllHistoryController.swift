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

/// Manages "all history" that is, all the documents stored in dime, and allows to manipulate some of that history
class AllHistoryController: NSViewController, DiMeReceiverDelegate, NSTableViewDataSource, NSTableViewDelegate {
    
    // MARK: - For external (outside ui, e.g. ipc) sessionId selection
    
    /// Whether there is loading ongoing.
    var loading = true { didSet {
        if let sesId = mustSelectSessionId where loading == false {
            mustSelectSessionId = nil
            if lastTriedSessionId != sesId {
                selectSessionId(sesId)
            } else {
                AppSingleton.log.debug("Could not find sessionId: '\(sesId)' even after reloading, opening instead.")
                // retreve scidoc and if found, open the document with the url associated to it
                diMeFetcher?.retrieveScientificDocument(forSessionId: sesId) {
                    sciDoc in
                    if let doc = sciDoc {
                        let fileUrl = NSURL(fileURLWithPath: doc.uri)
                        AppSingleton.appDelegate.openDocument(fileUrl, searchString: nil, focusArea: self.mustFocusOn[sesId])
                        self.mustFocusOn.removeValueForKey(sesId)
                    }
                }
            }
            lastTriedSessionId = sesId
        }
    } }
    
    /// Indicate a sessionId to select as soon as possible (useful for interprocess comm)
    var mustSelectSessionId: String? = nil
    
    /// Contains an area to focus on next time that the row corresponding to this
    /// sessionId is selected.
    private var mustFocusOn = [String: FocusArea]()
    
    /// Last sessionId that was asked to be retrieved after loading (used to prevent
    /// loops, yet signal that this id does not exist)
    var lastTriedSessionId = ""
    
    // MARK: - Setup
    
    var delegate: HistoryDetailDelegate?
    
    @IBOutlet weak var historyTable: NSTableView!
    var diMeFetcher: DiMeFetcher?
    
    var allHistoryTuples = [(ev: SummaryReadingEvent, ie: ScientificDocument?)]()
    
    var lastImportedSessionId = ""
    var lastImportedIndex = -1
    var lastSelectedSessionId = ""
    
    @IBOutlet weak var reloadButton: NSButton!
    @IBOutlet weak var loadingLabel: NSTextField!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    
    override func viewDidLoad() {
        // creates dime fetcher with self as receiver and prepares to receive table selection notifications
        diMeFetcher = DiMeFetcher(receiver: self)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(newHistoryTableSelection(_:)), name: NSTableViewSelectionDidChangeNotification, object: historyTable)
    }
    
    @objc private func newHistoryTableSelection(notification: NSNotification) {
        let selectedRow = historyTable.selectedRow
        guard selectedRow >= 0 else {
            return
        }
        let selectedSesId = allHistoryTuples[selectedRow].ev.sessionId
        if  selectedSesId != lastSelectedSessionId {
            delegate?.historyElementSelected((ev: allHistoryTuples[selectedRow].ev, ie: allHistoryTuples[selectedRow].ie!))
            if let f = mustFocusOn[allHistoryTuples[selectedRow].ev.sessionId] {
                mustFocusOn.removeValueForKey(allHistoryTuples[selectedRow].ev.sessionId)
                delegate?.focusOn(f)
            }
            lastSelectedSessionId = selectedSesId
        }
    }
    
    override func prepareForSegue(segue: NSStoryboardSegue, sender: AnyObject?) {
        if let segueId = segue.identifier where segueId == "showThresholdEditor" {
            let thresholdCont = segue.destinationController as! ThresholdEditor
            thresholdCont.detailDelegate = self.delegate
        }
    }
    
    // MARK: - Contextual menu
    
    /// Extracts a json file containing all (non-summary) reading events associated to the
    /// selected (summary) reading event, so that they can be analyzed by the eye tracking algo.
    /// Extracted json contains:
    /// - sessionId: String
    /// - rectangles: Array: one entry for each EyeRectangle
    @IBAction func extractJson(sender: NSMenuItem) {
        
        let row = historyTable.clickedRow
        delegate?.historyElementSelected((ev: allHistoryTuples[row].ev, ie: allHistoryTuples[row].ie!))
        let sessionId = allHistoryTuples[row].ev.sessionId
        let contentHash = allHistoryTuples[row].ie!.contentHash!
        
        // ask for output file first
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["json", "JSON"]
        panel.canSelectHiddenExtension = true
        panel.nameFieldStringValue = "\(sessionId).json"
        if panel.runModal() == NSFileHandlingPanelOKButton {
                
            let outURL = panel.URL!
            loadingStarted()
            
            diMeFetcher?.getNonSummaries(withSessionId: sessionId) {
                foundEvents in
                
                var outEyeRects = [EyeRectangle]()
                
                // check that info in dime matches selected file
                if let pdfb = self.delegate?.getPdfBase(), currentHash = pdfb.getDocText()?.sha1() where currentHash != contentHash {
                    AppSingleton.alertUser("Content of selected file does not match content stored in dime.", infoText: "Was the file moved / edited?")
                }
                
                // generate eye rectangles
                for event in foundEvents {
                    outEyeRects.appendContentsOf(EyeRectangle.allEyeRectangles(fromReadingEvent: event, forReadingClass: .Paragraph, andSource: .SMI, withPdfBase: self.delegate?.getPdfBase()))
                }
                
                if outEyeRects.count > 0 {
                    
                    // create object for json
                    var outArray = [AnyObject]()
                    for eyer in outEyeRects {
                        outArray.append(eyer.getDict())
                    }
                    
                    do {
                        // create data
                        var outDict = [String: AnyObject]()
                        outDict["sessionId"] = sessionId
                        outDict["rectangles"] = outArray
                        let options = NSJSONWritingOptions.PrettyPrinted
                        let outData = try NSJSONSerialization.dataWithJSONObject(outDict, options: options)
                        
                        
                            // create output file if it doesn't exist
                            if !NSFileManager.defaultManager().fileExistsAtPath(outURL.path!) {
                                NSFileManager.defaultManager().createFileAtPath(outURL.path!, contents: nil, attributes: nil)
                            } else {
                            // if file exists, delete it and create id
                                do {
                                    try NSFileManager.defaultManager().removeItemAtURL(outURL)
                                    NSFileManager.defaultManager().createFileAtPath(outURL.path!, contents: nil, attributes: nil)
                                } catch {
                                    AppSingleton.log.error("Could not delete file at \(outURL): \(error)")
                                }
                            }
                            
                            // write data to existing file
                            do {
                                let file = try NSFileHandle(forWritingToURL: outURL)
                                file.writeData(outData)
                            } catch {
                                AppSingleton.alertUser("Error while creating output file", infoText: "\(error)")
                            }
                            
                    } catch {
                        AppSingleton.alertUser("Error while serializing json")
                    }
                } else {
                    AppSingleton.alertUser("No matching data found")
                }
                
                self.loadingComplete()
            }
        }
    }
    
    /// Imports a json with computed eye data (contains attnVal for each rect)
    @IBAction func importJson(sender: NSMenuItem) {
        
        let row = historyTable.clickedRow
        if row >= 0 {
            delegate?.historyElementSelected((ev: allHistoryTuples[row].ev, ie: allHistoryTuples[row].ie!))
        
            let panel = NSOpenPanel()
            panel.allowedFileTypes = ["json", "JSON"]
            panel.beginSheetModalForWindow(self.view.window!, completionHandler: {
                result in
                if result == NSFileHandlingPanelOKButton {
                    let inURL = panel.URL!
                    let data = NSData(contentsOfURL: inURL)
                    let json = JSON(data: data!)
                    
                    // check that loaded session id matches selection
                    let fileSessionId = json["outData"]["sessionId"].stringValue
                    let tableSessionId = self.allHistoryTuples[row].ev.sessionId
                    if fileSessionId != tableSessionId {
                        AppSingleton.alertUser("Json file's id does not match table's id (selected wrong row or file?)")
                        
                        self.lastImportedIndex = -1
                        self.lastImportedSessionId = ""
                    } else {
                        
                        var outRects = [EyeRectangle]()
                        for outR in json["outData"]["outRects"].arrayValue {
                            outRects.append(EyeRectangle(fromJson: outR))
                        }
                        
                        // normalize imported rects so attnVal_n ranges between 0 and 1
                        outRects = outRects.normalize()
                        
                        self.performSegueWithIdentifier("showThresholdEditor", sender: self)
                        self.delegate?.setEyeRects(outRects)
                        
                        self.lastImportedIndex = row
                        self.lastImportedSessionId = tableSessionId
                    }
                } else {
                    self.lastImportedIndex = -1
                    self.lastImportedSessionId = ""
                }
            })
        } else {
            lastImportedIndex = -1
            lastImportedSessionId = ""
        }
        
    }
    
    /// Send the computed rectangles back to dime
    @IBAction func sendToDiMe(sender: NSMenuItem) {
        let row = historyTable.clickedRow
        if row >= 0 {
            let sessionId = allHistoryTuples[row].ev.sessionId
            guard row == lastImportedIndex && sessionId == lastImportedSessionId else {
                AppSingleton.alertUser("Last imported row and/or session id do not match (selected wrong row?)")
                return
            }
            guard lastImportedSessionId != "" && lastImportedIndex != -1 else {
                AppSingleton.alertUser("Nothing was imported last!")
                return
            }
            
            if let info = delegate!.getMarkings() {
                let summaryEvent = allHistoryTuples[row].ev
                summaryEvent.setProportions(info.pRead, pInteresting: info.pInteresting, pCritical: info.pCritical)
                summaryEvent.setRects(info.rects)
                DiMePusher.sendToDiMe(summaryEvent) {
                    success, _ in
                    if success {
                        AppSingleton.alertUser("Data successfully sent")
                    }
                }
            }
        
        }
    }
    
    // MARK: - DiMe communication
    
    /// Ask dime to fetch data
    func reloadData() {
        loadingStarted()
        diMeFetcher?.getSummaries()
    }
    
    /// Receive summaries from dime fetcher, as per protocol
    func receiveAllSummaries(tuples: [(ev: SummaryReadingEvent, ie: ScientificDocument?)]?) {
        if let t = tuples {
            allHistoryTuples = t
            historyTable.reloadData()
        } else {
            AppSingleton.alertUser("No data found.")
        }
        loadingComplete()
    }
    
    /// Update progress bar
    func updateProgress(received: Int, total: Int) {
        self.progressBar.doubleValue = Double(received) / Double(total)
    }
    
    // MARK: - Table delegate & data source
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return allHistoryTuples.count
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableColumn?.identifier == "HistoryList" {
            let listItem = tableView.makeViewWithIdentifier("HistoryListItem", owner: self) as! HistoryTableCell
            listItem.setValues(fromReadingEvent: allHistoryTuples[row].ev, sciDoc: allHistoryTuples[row].ie!)
            return listItem
        }
        else {
            return nil
        }
    }
    
    // MARK: - Convenience
    
    /// Focus on the given area, for the given sessionId. If another sessionId is selected,
    /// will focus on the next refresh.
    func focusOn(area: FocusArea, forSessionId: String) {
        if forSessionId == lastSelectedSessionId {
            delegate?.focusOn(area)
        } else {
            mustFocusOn[forSessionId] = area
        }
    }
    
    /// Selects a given sessionId in the table. If the given sessionId is not in the
    /// list of tuples (or loading is ongoing), orders a refresh (will try to fetch this sessionId once loading
    /// completes).
    func selectSessionId(sessionId: String) {
        guard loading == false else {
            mustSelectSessionId = sessionId
            return
        }
        let tuples = allHistoryTuples.filter({$0.ev.sessionId == sessionId})
        guard tuples.count != 0 else {
            mustSelectSessionId = sessionId
            reloadData()
            return
        }
        guard let i = allHistoryTuples.indexOf({$0.ev.sessionId == sessionId}) else {
            return  // this should never happen
        }
        historyTable.selectRowIndexes(NSIndexSet(index: i), byExtendingSelection: false)
    }
    
    func loadingStarted() {
        loading = true
        dispatch_async(dispatch_get_main_queue()) {
            self.progressBar.doubleValue = 0
            self.historyTable.enabled = false
            self.historyTable.alphaValue = 0.4
            self.progressBar.hidden = false
            self.loadingLabel.hidden = false
            self.reloadButton.enabled = false
        }
    }
    
    func loadingComplete() {
        dispatch_async(dispatch_get_main_queue()) {
            self.progressBar.doubleValue = 1
            self.historyTable.enabled = true
            self.historyTable.alphaValue = 1
            self.progressBar.hidden = true
            self.loadingLabel.hidden = true
            self.reloadButton.enabled = true
            self.loading = false
        }
    }
}
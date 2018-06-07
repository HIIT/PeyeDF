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

import Foundation
import Cocoa
import os.log

/// Manages "all history" that is, all the documents stored in dime, and allows to manipulate some of that history
class AllHistoryController: NSViewController, DiMeReceiverDelegate, NSTableViewDataSource, NSTableViewDelegate {
    
    // MARK: - For external (outside ui, e.g. ipc) sessionId selection
    
    /// Whether there is loading ongoing.
    var loading = true { didSet {
        if let sesId = mustSelectSessionId , loading == false {
            mustSelectSessionId = nil
            if lastTriedSessionId != sesId {
                selectSessionId(sesId)
            } else {
                if #available(OSX 10.12, *) {
                    os_log("Could not find sessionId: %@ even after reloading, opening instead.", type: .debug, sesId)
                }
                // retreve scidoc and if found, open the document with the url associated to it
                diMeFetcher?.retrieveScientificDocument(forSessionId: sesId) {
                    sciDoc in
                    if let doc = sciDoc {
                        let fileUrl = URL(fileURLWithPath: doc.uri)
                        AppSingleton.appDelegate.openDocument(fileUrl, focusArea: self.mustFocusOn[sesId])
                        self.mustFocusOn.removeValue(forKey: sesId)
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
    fileprivate var mustFocusOn = [String: FocusArea]()
    
    /// Last sessionId that was asked to be retrieved after loading (used to prevent
    /// loops, yet signal that this id does not exist)
    var lastTriedSessionId = ""
    
    // MARK: - Setup
    
    @IBOutlet weak var noDataLabel: NSTextField!
    
    var delegate: HistoryDetailDelegate?
    
    @IBOutlet weak var historyTable: NSTableView!
    var diMeFetcher: DiMeFetcher?
    
    var allHistoryTuples = [(ev: SummaryReadingEvent, ie: ScientificDocument)]()
    
    var lastImportedSessionId = ""
    var lastImportedIndex = -1
    var lastSelectedSessionId = ""
    
    @IBOutlet weak var reloadButton: NSButton!
    @IBOutlet weak var loadingLabel: NSTextField!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    
    override func viewDidLoad() {
        // creates dime fetcher with self as receiver and prepares to receive table selection notifications
        diMeFetcher = DiMeFetcher(receiver: self)
        progressBar.bind(NSBindingName(rawValue: "value"), to: diMeFetcher!.fetchProgress, withKeyPath: "fractionCompleted")
        NotificationCenter.default.addObserver(self, selector: #selector(newHistoryTableSelection(_:)), name: NSTableView.selectionDidChangeNotification, object: historyTable)
    }
    
    /// Perform search using default methods.
    @objc func performFindPanelAction(_ sender: AnyObject) {
        switch UInt(sender.tag) {
        case NSFindPanelAction.showFindPanel.rawValue:
            self.view.window?.makeFirstResponder(searchField)
        default:
            break
        }
    }
    
    @objc fileprivate func newHistoryTableSelection(_ notification: Notification) {
        let selectedRow = historyTable.selectedRow
        guard selectedRow >= 0 else {
            return
        }
        let selectedSesId = allHistoryTuples[selectedRow].ev.sessionId
        if  selectedSesId != lastSelectedSessionId {
            delegate?.historyElementSelected((ev: allHistoryTuples[selectedRow].ev, ie: allHistoryTuples[selectedRow].ie))
            if let f = mustFocusOn[allHistoryTuples[selectedRow].ev.sessionId] {
                mustFocusOn.removeValue(forKey: allHistoryTuples[selectedRow].ev.sessionId)
                delegate?.focusOn(f)
            }
            lastSelectedSessionId = selectedSesId
        }
    }
    
    /// Double click in table opens document
    @IBAction func doubleAction(_ sender: NSTableView) {
        delegate?.openLastHistoryElement()
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let segueId = segue.identifier , segueId.rawValue == "showThresholdEditor" {
            let thresholdCont = segue.destinationController as! ThresholdEditor
            thresholdCont.detailDelegate = self.delegate
        }
    }
    
    // MARK: - Search
    
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var documentsRadio: NSButton!
    @IBOutlet weak var seenTextRadio: NSButton!
    @IBOutlet weak var tagsRadio: NSButton!
    
    fileprivate(set) var searchIn: DiMeSearchableItem = .sciDoc { didSet {
        let radioButtons: [NSButton] = [documentsRadio, seenTextRadio, tagsRadio]
        radioButtons.forEach() {
            button in
            DispatchQueue.main.async {
                if button.tag == self.searchIn.rawValue {
                    button.state = .on
                } else {
                    button.state = .off
                }
            }
        }
    } }
    
    @IBAction func searchRadioPress(_ sender: NSButton) {
        let newSearchIn = DiMeSearchableItem(rawValue: sender.tag)!
        if newSearchIn != searchIn {
            searchIn = newSearchIn
            if searchField.stringValue != "" {
                reloadData()
            }
        }
    }
    
    // MARK: - Contextual menu
    
    /// Delete the session related to the currently selected summary event
    @IBAction func deleteMenuAction(_ sender: NSMenuItem) {
        guard historyTable.clickedRow >= 0 else {
            return
        }
        
        let row = historyTable.clickedRow

        DispatchQueue.global(qos: .userInitiated).async {
            DiMeEraser.deleteAllEvents(relatedToSessionId: self.allHistoryTuples[row].ev.sessionId)
            self.reloadData()
        }
    }
    
    /// Extracts a json file containing all (non-summary) reading events associated to the
    /// selected (summary) reading event, so that they can be analyzed by the eye tracking algo.
    /// Extracted json contains:
    /// - sessionId: String
    /// - rectangles: Array: one entry for each EyeRectangle
    @IBAction func extractJson(_ sender: NSMenuItem) {
        
        let row = historyTable.clickedRow
        delegate?.historyElementSelected((ev: allHistoryTuples[row].ev, ie: allHistoryTuples[row].ie))
        let sessionId = allHistoryTuples[row].ev.sessionId
        let contentHash = allHistoryTuples[row].ie.contentHash!
        
        // ask for output file first
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["json", "JSON"]
        panel.canSelectHiddenExtension = true
        panel.nameFieldStringValue = "\(sessionId).json"
        if panel.runModal().rawValue == NSFileHandlingPanelOKButton {
                
            let outURL = panel.url!
            loadingStarted()
            
            diMeFetcher?.retrieveNonSummaries(withSessionId: sessionId) {
                foundEvents in
                
                var outEyeRects = [EyeRectangle]()
                
                // check that info in dime matches selected file
                if let pdfb = self.delegate?.getPdfBase(), let currentHash = pdfb.getDocText()?.sha1() , currentHash != contentHash {
                    AppSingleton.alertUser("Content of selected file does not match content stored in dime.", infoText: "Was the file moved / edited?")
                }
                
                // generate eye rectangles
                for event in foundEvents {
                    outEyeRects.append(contentsOf: EyeRectangle.allEyeRectangles(fromReadingEvent: event, forReadingClass: .paragraph, andSource: .smi, withPdfBase: self.delegate?.getPdfBase()))
                }
                
                if outEyeRects.count > 0 {
                    
                    // create object for json
                    var outArray = [Any]()
                    for eyer in outEyeRects {
                        outArray.append(eyer.getDict())
                    }
                    
                    do {
                        // create data
                        var outDict = [String: Any]()
                        outDict["sessionId"] = sessionId
                        outDict["rectangles"] = outArray
                        let options = JSONSerialization.WritingOptions.prettyPrinted
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
                                    if #available(OSX 10.12, *) {
                                        os_log("Could not delete file at %@: %@", type: .error, outURL.relativePath, error.localizedDescription)
                                    }
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
    @IBAction func importJson(_ sender: NSMenuItem) {
        
        let row = historyTable.clickedRow
        if row >= 0 {
            delegate?.historyElementSelected((ev: allHistoryTuples[row].ev, ie: allHistoryTuples[row].ie))
        
            let panel = NSOpenPanel()
            panel.allowedFileTypes = ["json", "JSON"]
            panel.beginSheetModal(for: self.view.window!, completionHandler: {
                result in
                if result.rawValue == NSFileHandlingPanelOKButton,
                   let inURL = panel.url,
                   let data = try? Data(contentsOf: inURL),
                   let json = try? JSON(data: data) {
                    
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
                        
                        self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "showThresholdEditor"), sender: self)
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
    @IBAction func sendToDiMe(_ sender: NSMenuItem) {
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
                summaryEvent.setProportions(nil, info.pRead, info.pInteresting, info.pCritical)
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
        DispatchQueue.main.async {
            [weak self] in
            
            guard let strongSelf = self else {
                return
            }
            
            if strongSelf.searchField.stringValue == "" {
                AppSingleton.findPasteboard.clearContents()
                strongSelf.delegate?.setSearchString(newString: nil)
                strongSelf.diMeFetcher?.getAllSummaries()
            } else {
                AppSingleton.findPasteboard.declareTypes([.string], owner: nil)
                AppSingleton.findPasteboard.setString(strongSelf.searchField.stringValue, forType: .string)
                if strongSelf.searchIn == .tag {
                    strongSelf.delegate?.setSearchString(newString: "#tag:" + strongSelf.searchField.stringValue)
                } else {
                    strongSelf.delegate?.setSearchString(newString: strongSelf.searchField.stringValue)
                }
                strongSelf.diMeFetcher?.getSummariesForSearch(string: strongSelf.searchField.stringValue, inData: strongSelf.searchIn)
            }
        }
    }
    
    /// Receive summaries from dime fetcher, as per protocol
    func receiveAllSummaries(_ tuples: [(ev: SummaryReadingEvent, ie: ScientificDocument)]?) {
        if let t = tuples {
            allHistoryTuples = t
            DispatchQueue.main.async {
                self.historyTable.reloadData()
                self.noDataLabel.isHidden = true
            }
        } else {
            allHistoryTuples = []
            DispatchQueue.main.async {
                self.historyTable.reloadData()
                self.noDataLabel.isHidden = false
            }
        }
        loadingComplete()
    }
    
        // MARK: - Table delegate & data source
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return allHistoryTuples.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableColumn?.identifier == NSUserInterfaceItemIdentifier(rawValue: "HistoryList") {
            let listItem = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HistoryListItem"), owner: self) as! HistoryTableCell
            listItem.setValues(fromReadingEvent: allHistoryTuples[row].ev, sciDoc: allHistoryTuples[row].ie)
            return listItem
        } else {
            return nil
        }
    }
    
    // MARK: - Convenience
    
    /// Focus on the given area, for the given sessionId. If another sessionId is selected,
    /// will focus on the next refresh.
    func focusOn(_ area: FocusArea, forSessionId: String) {
        if forSessionId == lastSelectedSessionId {
            delegate?.focusOn(area)
        } else {
            mustFocusOn[forSessionId] = area
        }
    }
    
    /// Selects a given sessionId in the table. If the given sessionId is not in the
    /// list of tuples (or loading is ongoing), orders a refresh (will try to fetch this sessionId once loading
    /// completes).
    func selectSessionId(_ sessionId: String) {
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
        guard let i = allHistoryTuples.index(where: {$0.ev.sessionId == sessionId}) else {
            return  // this should never happen
        }
        historyTable.selectRowIndexes(IndexSet(integer: i), byExtendingSelection: false)
    }
    
    func loadingStarted() {
        loading = true
        DispatchQueue.main.async {
            self.progressBar.doubleValue = 0
            self.historyTable.isEnabled = false
            self.historyTable.alphaValue = 0.4
            self.progressBar.isHidden = false
            self.loadingLabel.isHidden = false
            self.reloadButton.isEnabled = false
        }
    }
    
    func loadingComplete() {
        DispatchQueue.main.async {
            self.progressBar.doubleValue = 1
            self.historyTable.isEnabled = true
            self.historyTable.alphaValue = 1
            self.progressBar.isHidden = true
            self.loadingLabel.isHidden = true
            self.reloadButton.isEnabled = true
            self.loading = false
        }
    }
}

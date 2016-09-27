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
import Foundation

/// Used to allow the search panel controller to communicate with others
protocol SearchProvider: class {
    
    /// Returns true if there is a result avaiable
    func hasResult() -> Bool
    
    /// Performs the requested search using the given string.
    /// -parameter exact: If false, words will be separated
    func doSearch(_: String, exact: Bool)
    
    /// Gets the next found item
    func selectNextResult(_ sender: AnyObject?)
    
    /// Gets the previous found item
    func selectPreviousResult(_ sender: AnyObject?)
    
}

class SearchPanelController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, SearchProvider {
    
    // make sure these match in IB
    let kColumnTitlePageNumber = "Page #"
    let kColumnTitlePageLabel = "Page Label"
    let kColumnTitleLine = "Line"
    
    // String used to make tag searches
    let kTagSString = TagConstants.tagSearchPrefix
    
    /// The column which contains labels (is collapsed if numbers==labels)
    @IBOutlet weak var labelColumn: NSTableColumn!
    
    /// Default width for label column width when displayed
    let kLabelColumnWidth: CGFloat = 68.0
    
    // delay for making first responder
    let kFirstResponderDelay = 0.2
    
    @IBOutlet weak var resultNumberField: NSTextField!
    @IBOutlet weak var resultTable: NSTableView!
    
    @IBOutlet weak var searchCell: NSSearchFieldCell!
    @IBOutlet weak var searchField: NSSearchField!
    
    @IBOutlet weak var previousButton: NSButton!
    @IBOutlet weak var nextButton: NSButton!
    
    /// The string that was inputted for search
    var searchString: String = ""
    var exactMatch: Bool = true
    weak var selectedSelection: PDFSelection?
    
    // Option buttons
    @IBOutlet weak var separateWordsButton: NSButton!
    @IBOutlet weak var exactMatchButton: NSButton!
    
    weak var pdfReader: PDFReader?
    
    /// Keeps track of the number of results found
    var numberOfResultsFound = 0
    
    /// Keeps instances of found selections
    var foundSelections = [PDFSelection]()
    
    @IBAction func exactMatchPress(_ sender: NSButton) {
        exactMatch = true
        separateWordsButton.state = NSOffState
    }
    
    @IBAction func separateWordsPress(_ sender: NSButton) {
        exactMatch = false
        exactMatchButton.state = NSOffState
    }
    
    // MARK: - Loading / unloading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        labelColumn.minWidth = 0.0
        self.view.frame = NSRect()  // hide the search panel on launch
    }
    
    override func viewWillAppear() {
        // recents menu --
        let cellMenu = NSMenu(title: NSLocalizedString("recentSearchMenu.title", value: "Search Menu", comment: "Search menu title"))
        let clearMenuItem = NSMenuItem(title: NSLocalizedString("recentSearchMenu.clear", value: "Clear", comment: "Clear recent searches menu item"), action: nil, keyEquivalent: "")
        clearMenuItem.tag = Int(NSSearchFieldClearRecentsMenuItemTag)
        cellMenu.insertItem(clearMenuItem, at: 0)
        
        let menuSep = NSMenuItem.separator()
        menuSep.tag = Int(NSSearchFieldRecentsTitleMenuItemTag)
        cellMenu.insertItem(menuSep, at: 1)
        
        let recentSearchMenuItem = NSMenuItem(title: NSLocalizedString("recentSearchMenu.recentSearches", value: "Recent Searches", comment: "Recent searches menu item"), action: nil, keyEquivalent: "")
        recentSearchMenuItem.tag = Int(NSSearchFieldRecentsTitleMenuItemTag)
        cellMenu.insertItem(recentSearchMenuItem, at: 2)
        
        let recentMenu = NSMenuItem(title: "Recents", action: nil, keyEquivalent: "")
        recentMenu.tag = Int(NSSearchFieldRecentsMenuItemTag)
        cellMenu.insertItem(recentMenu, at: 3)
        
        searchCell.searchMenuTemplate = cellMenu
        // end recents menu --
        
        // table set
        resultTable.dataSource = self
        resultTable.delegate = self
    }
    
    override func viewDidAppear() {
        // set up PDFView search notification
        NotificationCenter.default.addObserver(self, selector: #selector(foundPDFSearchItem(_:)), name: NSNotification.Name.PDFDocumentDidFindMatch, object: pdfReader!.document)
        // set up PDFBase tag search notification
        NotificationCenter.default.addObserver(self, selector: #selector(foundPDFSearchItem(_:)), name: NSNotification.Name(rawValue: TagConstants.tagStringFoundNotification), object: pdfReader!)
    }
    
    override func viewWillDisappear() {
        // unset search notifications
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.PDFDocumentDidFindMatch, object: pdfReader!.document)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: TagConstants.tagStringFoundNotification), object: pdfReader!)
        
        // table unset
        resultTable.dataSource = nil
        resultTable.delegate = nil
        
    }
    
    // MARK: - UI various
    
    /// Show label column if needed
    func labelColumnCheck() {
        if pdfReader!.pageNumbersSameAsLabels() {
            labelColumn.width = 0
        } else {
            labelColumn.width = kLabelColumnWidth
        }
    }
    
    /// Make the search field first responder, but with a delay
    func makeSearchFieldFirstResponderWithDelay() {
        labelColumnCheck()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + kFirstResponderDelay) {
            [weak self] in
            guard self != nil else {
                return
            }
            if let oldString = AppSingleton.findPasteboard.stringValue {
                self?.searchField.stringValue = oldString
            }
            self!.view.window?.makeFirstResponder(self!.searchField)
        }
    }
    
    // MARK: - SearchProvider implementation
    
    func hasResult() -> Bool {
        return numberOfResultsFound != 0
    }
    
    @IBAction func selectPreviousResult(_ sender: AnyObject?) {
        if hasResult() {
            let selectedRow = resultTable.selectedRow  // is -1 if nothing
            
            // if nothing is selected, or first is selected, select last
            if selectedRow == -1 || selectedRow == 0 {
                resultTable.selectRowIndexes(IndexSet(integer: numberOfResultsFound - 1), byExtendingSelection: false)
                
            // otherwise select selectedRow -1
            } else {
                resultTable.selectRowIndexes(IndexSet(integer: selectedRow - 1), byExtendingSelection: false)
            }
            resultTable.scrollRowToVisible(resultTable.selectedRow)
        }
    }
    
    @IBAction func selectNextResult(_ sender: AnyObject?) {
        if hasResult() {
            let selectedRow = resultTable.selectedRow  // is -1 if nothing
            
            // if nothing is selected, or last is selected, select first
            if selectedRow == -1 || selectedRow == numberOfResultsFound - 1 {
                resultTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                
            // otherwise select selectedRow +1
            } else {
                resultTable.selectRowIndexes(IndexSet(integer: selectedRow + 1), byExtendingSelection: false)
            }
            resultTable.scrollRowToVisible(resultTable.selectedRow)
        }
    }
    
    /// Performs a search using the given string, with the exact phrase flag.
    /// If the string is between quotes ("something") forces an exact phrase search.
    /// If the string starts with "#tag:" (kTagSString) searches for tags with that name instead.
    func doSearch(_ theString: String, exact: Bool) {
        var theString = theString
        var exact = exact
        
        // -- check if recent search element is present in recent searches --
        let recentSearches = searchCell.recentSearches
        // if list is empty add it
        if (recentSearches!.isEmpty) {
            searchCell.recentSearches.append(theString)
        } else {
            for i in 0 ..< recentSearches!.count {
                // if item present, remove it
                let item = recentSearches![i]
                if item == searchString {
                    searchCell.recentSearches.remove(at: i)
                    break
                }
            }
            // add it at "bottom of list"
            searchCell.recentSearches.append(theString)
        }
        // -- end recent searches check --
        
        // if the string contains two quotes, at beginning and end, 
        // remove them and perform exact search
        if theString.countOfChar("\"") == 2 && theString.characters.first! == "\"" && theString.characters.last! == "\"" {
            theString.removeChars(["\""])
            exact = true
        }
        
        // reset exact flag and button in case we are called from outside ui
        exactMatch = exact
        if exact {
            exactMatchButton.state = NSOnState
            separateWordsButton.state = NSOffState
        } else {
            separateWordsButton.state = NSOnState
            exactMatchButton.state = NSOffState
        }
        
        if searchField.stringValue != theString {
            searchField.stringValue = theString
        }
        searchString = searchField.stringValue
        
        numberOfResultsFound = 0
        foundSelections = [PDFSelection]()
        resultNumberField.stringValue = "\(numberOfResultsFound)"
        resultTable.reloadData()
        selectedSelection = nil
        
        if theString.hasPrefix(kTagSString) {
            // tag search
            
            // get wanted text of tag from string (if present)
            guard let r = theString.range(of: kTagSString) else {
                return
            }
            let tagString = theString.substring(from: r.upperBound)
            guard tagString.characters.count > 0 else {
                return
            }
            
            pdfReader!.beginTagStringSearch(tagString)
            
        } else {
            
            // normal search
            if exact {
                pdfReader!.document!.beginFindString(theString, withOptions: Int(NSString.CompareOptions.caseInsensitive.rawValue))
            } else {
                guard let searchS = theString.split(" ") else {
                    return
                }
                pdfReader!.document!.beginFind(searchS, withOptions: Int(NSString.CompareOptions.caseInsensitive.rawValue))
            }
        }
        
        previousButton.isEnabled = false
        nextButton.isEnabled = false
    }
    
    // MARK: - Other search
    
    /// Some text has been entered in the search field
    @IBAction func startSearch(_ sender: NSSearchField) {
        if pdfReader!.document!.isFinding {
            pdfReader!.document!.cancelFindString()
        }
        if pdfReader!.searching {
            pdfReader!.searching = false
        }
        doSearch(sender.stringValue, exact: exactMatch)
    }
    
    // MARK: - Notification callbacks
    
    @objc func foundPDFSearchItem(_ notification: Notification) {
        let infoDict = (notification as NSNotification).userInfo as! [String: AnyObject]
        
        let pdfSel: PDFSelection
        // discriminate between pdfView string and MyPDF tag string searches
        if notification.name == NSNotification.Name.PDFDocumentDidFindMatch {
            pdfSel = infoDict["PDFDocumentFoundSelection"] as! PDFSelection
        } else if notification.name.rawValue == TagConstants.tagStringFoundNotification {
            pdfSel = infoDict["MyPDFTagFoundSelection"] as! PDFSelection
        } else {
            fatalError("Unrecognized notification name!")
        }
        
        numberOfResultsFound += 1
        foundSelections.append(pdfSel.copy() as! PDFSelection)
        self.resultTable.noteNumberOfRowsChanged()
        let updateRect = self.resultTable.rect(ofRow: self.numberOfResultsFound)
        self.resultTable.setNeedsDisplay(updateRect)
        resultNumberField.stringValue = "\(numberOfResultsFound)"
        
        if numberOfResultsFound > 1 {
            nextButton.isEnabled = true
            previousButton.isEnabled = true
        }
    }
    
    // MARK: - Table data source
    
    func numberOfRows(in aTableView: NSTableView) -> Int {
        return foundSelections.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        
        let pages = foundSelections[row].pages
        
        // check that foundSelections contains valid data first and unwrap values
        guard foundSelections.count > row && foundSelections[row].pages.count > 0 &&
              pages.count > 0, let document = pages[0].document else {
            return nil
        }
        
        let page = pages[0]
        
        if tableColumn?.identifier == kColumnTitlePageLabel {
            
            // get found selection for this row
            return page.label
            
        } else if tableColumn?.identifier == kColumnTitlePageNumber {
            
            return document.index(for: page) + 1
            
        } else if tableColumn?.identifier == kColumnTitleLine {
            
            // extract line from found selection
            let foundString = foundSelections[row].string
            let lineString = foundSelections[row].lineString() as NSString
            
            // make found result bold
            let attrString = NSMutableAttributedString(string: lineString as String)
            let rangeOfQuery = lineString.range(of: foundString!, options: NSString.CompareOptions.caseInsensitive)
            let boldFont = NSFont.boldSystemFont(ofSize: 12.0)
            attrString.beginEditing()
            attrString.addAttribute(NSFontAttributeName, value: boldFont, range: rangeOfQuery)
            attrString.endEditing()
            return attrString
        }
        return nil
    }
    
    // MARK: - Table delegate
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tabView = notification.object as! NSTableView
        let rowIndex = tabView.selectedRow
        if rowIndex >= 0 {
            let selectedResult = foundSelections[rowIndex]
            pdfReader?.foundResult(selectedResult)
        }
    }
}

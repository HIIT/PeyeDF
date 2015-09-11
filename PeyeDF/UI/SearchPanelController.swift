//
//  SearchPanelController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 10/09/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Cocoa
import Quartz
import Foundation

class SearchPanelController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    // make sure these match in IB
    let kColumnTitlePageNumber = "Page #"
    let kColumnTitlePageLabel = "Page Label"
    let kColumnTitleLine = "Line"
    
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
    
    var searchString: String = ""
    weak var selectedSelection: PDFSelection?
    
    weak var pdfView: MyPDF?
    
    /// Keeps track of the number of results found
    var numberOfResultsFound = 0
    
    /// Keeps instances of found selections
    var foundSelections = [PDFSelection]()
    
    // MARK: - Loading / unloading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        labelColumn.minWidth = 0.0
    }
    
    override func viewWillAppear() {
        // recents menu --
        let cellMenu = NSMenu(title: NSLocalizedString("recentSearchMenu.title", value: "Search Menu", comment: "Search menu title"))
        let clearMenuItem = NSMenuItem(title: NSLocalizedString("recentSearchMenu.clear", value: "Clear", comment: "Clear recent searches menu item"), action: nil, keyEquivalent: "")
        clearMenuItem.tag = Int(NSSearchFieldClearRecentsMenuItemTag)
        cellMenu.insertItem(clearMenuItem, atIndex: 0)
        
        let menuSep = NSMenuItem.separatorItem()
        menuSep.tag = Int(NSSearchFieldRecentsTitleMenuItemTag)
        cellMenu.insertItem(menuSep, atIndex: 1)
        
        let recentSearchMenuItem = NSMenuItem(title: NSLocalizedString("recentSearchMenu.recentSearches", value: "Recent Searches", comment: "Recent searches menu item"), action: nil, keyEquivalent: "")
        recentSearchMenuItem.tag = Int(NSSearchFieldRecentsTitleMenuItemTag)
        cellMenu.insertItem(recentSearchMenuItem, atIndex: 2)
        
        let recentMenu = NSMenuItem(title: "Recents", action: nil, keyEquivalent: "")
        recentMenu.tag = Int(NSSearchFieldRecentsMenuItemTag)
        cellMenu.insertItem(recentMenu, atIndex: 3)
        
        searchCell.searchMenuTemplate = cellMenu
        // end recents menu --
        
        // table set
        resultTable.setDataSource(self)
        resultTable.setDelegate(self)
        
        // set up search notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "foundOneMatch:", name: PDFDocumentDidFindMatchNotification, object: pdfView!.document())
    }
    
    override func viewWillDisappear() {
        // unset search notifications
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PDFDocumentDidFindMatchNotification, object: pdfView!.document())
        
        // table unset
        resultTable.setDataSource(nil)
        resultTable.setDelegate(nil)
        
    }
    
    // MARK: - UI various
    
    /// Show label column if needed
    func labelColumnCheck() {
        if pdfView!.pageNumbersSameAsLabels() {
            labelColumn.width = 0
        } else {
            labelColumn.width = kLabelColumnWidth
        }
    }
    
    /// Make the search field first responder, but with a delay
    func makeSearchFieldFirstResponderWithDelay() {
        labelColumnCheck()
        NSTimer.scheduledTimerWithTimeInterval(kFirstResponderDelay, target: self, selector: "makeSearchFieldFirstResponder", userInfo: nil, repeats: false)
    }
    
    /// Make the search field the first reponder (i.e. focus on it)
    @objc func makeSearchFieldFirstResponder() {
        searchField.becomeFirstResponder()
    }
    
    // MARK: - Search-related
    
    /// Some text has been entered in the search field
    @IBAction func startSearch(sender: NSSearchField) {
        if pdfView!.document().isFinding() {
            pdfView!.document().cancelFindString()
        }
        
        numberOfResultsFound = 0
        searchString = sender.stringValue
        foundSelections = [PDFSelection]()
        resultNumberField.stringValue = "\(numberOfResultsFound)"
        resultTable.reloadData()
        selectedSelection = nil
        
        pdfView!.document().beginFindString(sender.stringValue, withOptions: Int(NSStringCompareOptions.CaseInsensitiveSearch.rawValue))
    }
    
    // MARK: - Notification callbacks
    
    @objc func foundOneMatch(notification: NSNotification) {
        let infoDict = notification.userInfo as! [String: AnyObject]
        let pdfSel = infoDict["PDFDocumentFoundSelection"] as! PDFSelection
        
        numberOfResultsFound += 1
        foundSelections.append(pdfSel.copy() as! PDFSelection)
        resultTable.reloadData()
        resultNumberField.stringValue = "\(numberOfResultsFound)"
    }
    
    // MARK: - Table data source
    
    func numberOfRowsInTableView(aTableView: NSTableView) -> Int {
        return count(foundSelections)
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        if tableColumn?.identifier == kColumnTitlePageLabel {
            
            // get found selection for this row
            let pages = foundSelections[row].pages()
            let page = pages[0] as! PDFPage
            return page.label()
            
        } else if tableColumn?.identifier == kColumnTitlePageNumber {
            
            let pages = foundSelections[row].pages()
            let page = pages[0] as! PDFPage
            return pdfView!.document().indexForPage(page) + 1
            
        } else if tableColumn?.identifier == kColumnTitleLine {
            
            // extract line from found selection
            let pages = foundSelections[row].pages()
            let page = pages[0] as! PDFPage
            let selRect = foundSelections[row].boundsForPage(page)
            let selPoint = NSPoint(x: selRect.origin.x + selRect.width / 2, y: selRect.origin.y + selRect.height / 2)
            let lineSel = page.selectionForLineAtPoint(selPoint)
            let lineString: NSString = lineSel.string()
            
            // make found result bold
            let rangeOfQuery = lineString.rangeOfString(searchString, options: NSStringCompareOptions.CaseInsensitiveSearch)
            let boldFont = NSFont.boldSystemFontOfSize(12.0)
            let attrString = NSMutableAttributedString(string: lineString as String)
            attrString.beginEditing()
            attrString.addAttribute(NSFontAttributeName, value: boldFont, range: rangeOfQuery)
            attrString.endEditing()
            return attrString
        }
        return nil
    }
    
    // MARK: - Table delegate
    
    func tableViewSelectionDidChange(notification: NSNotification) {
        let highlightDelay = 0.2
        
        let tabView = notification.object as! NSTableView
        let rowIndex = tabView.selectedRow
        if rowIndex >= 0 {
            let selectedResult = foundSelections[rowIndex]
            pdfView?.setCurrentSelection(selectedResult, animate: false)
            pdfView?.scrollSelectionToVisible(self)
            pdfView?.setCurrentSelection(selectedResult, animate: true)
        }
    }
}

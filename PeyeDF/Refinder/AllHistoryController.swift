//
//  AllHistoryController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 20/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa

/// This protocol is implemeted by classes that want to display in detail an history element (which is a tuple of ReadingEvent and ScientificDocument). Used to inform the pdf history display classes on which history item was selected
protocol HistoryDetailDelegate {
    
    /// Tells the delegate that a new item was selected
    func historyElementSelected(tuple: (ev: ReadingEvent, ie: ScientificDocument))
}

class AllHistoryController: NSViewController, DiMeReceiverDelegate, NSTableViewDataSource, NSTableViewDelegate {
    
    var delegate: HistoryDetailDelegate?
    
    @IBOutlet weak var historyTable: NSTableView!
    var diMeFetcher: DiMeFetcher?
    
    var allHistoryTuples = [(ev: ReadingEvent, ie: ScientificDocument?)]()
    
    override func viewDidLoad() {
        // creates dime fetcher with self as receiver and prepares to receive table selection notifications
        diMeFetcher = DiMeFetcher(receiver: self)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "newHistoryTableSelection:", name: NSTableViewSelectionDidChangeNotification, object: historyTable)
    }
    
    @objc private func newHistoryTableSelection(notification: NSNotification) {
        let selectedRow = historyTable.selectedRow
        if selectedRow >= 0 {
            delegate?.historyElementSelected((ev: allHistoryTuples[selectedRow].ev, ie: allHistoryTuples[selectedRow].ie!))
        }
    }
    
    // MARK: - DiMe communication
    
    /// Ask dime to fetch data
    func reloadData() {
        diMeFetcher?.getSummaries()
    }
    
    /// Receive summaries from dime fetcher, as per protocol
    func receiveAllSummaries(tuples: [(ev: ReadingEvent, ie: ScientificDocument?)]) {
        allHistoryTuples = tuples
        historyTable.reloadData()
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
}
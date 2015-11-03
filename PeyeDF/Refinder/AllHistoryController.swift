//
//  AllHistoryController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 20/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa

class AllHistoryController: NSViewController, DiMeReceiverDelegate, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var historyTable: NSTableView!
    var diMeFetcher: DiMeFetcher?
    
    var allHistoryTuples = [(ev: ReadingEvent, ie: ScientificDocument?)]()
    
    override func viewDidLoad() {
        diMeFetcher = DiMeFetcher(receiver: self)
    }
    
    func reloadData() {
        diMeFetcher?.getSummaries()
    }
    
    func receiveAllSummaries(tuples: [(ev: ReadingEvent, ie: ScientificDocument?)]) {
        allHistoryTuples = tuples
        historyTable.reloadData()
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return allHistoryTuples.count
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableColumn?.identifier == "HistoryList" {
            let listItem = tableView.makeViewWithIdentifier("HistoryListItem", owner: self) as! HistoryTableCell
            listItem.setValues(fromReadingEvent: allHistoryTuples[row].ev, sciDoc: allHistoryTuples[row].ie)
            return listItem
        }
        else {
            return nil
        }
    }
}
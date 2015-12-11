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

/// AllHistoryController 
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
    
    // MARK: - Contextual menu
    
    /// Extracts a json file containing all (non-summary) reading events associated to the
    /// selected (summary) reading event, so that they can be analyzed by the eye tracking algo.
    /// Extracted json contains:
    /// - sessionId: String
    /// - rectangles: Array: one entry for each EyeRectangle
    @IBAction func extractJson(sender: NSMenuItem) {
        let rwc = self.view.window!.windowController! as! RefinderWindowController
        rwc.loadingStarted()
        let row = historyTable.clickedRow
        let sessionId = allHistoryTuples[row].ev.sessionId
        diMeFetcher?.getNonSummaries(withSessionId: sessionId) {
            foundEvents in
            Swift.print("Matching events: \(foundEvents.count)")
            
            var outEyeRects = [EyeRectangle]()
            
            // generate eye rectangles
            for event in foundEvents {
                outEyeRects.appendContentsOf(EyeRectangle.allEyeRectangles(fromReadingEvent: event))
            }
            
            if outEyeRects.count > 0 {
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
                    
                    // save data
                    let panel = NSSavePanel()
                    panel.allowedFileTypes = ["json", "JSON"]
                    panel.canSelectHiddenExtension = true
                    panel.nameFieldStringValue = "\(sessionId).json"
                    if panel.runModal() == NSFileHandlingPanelOKButton {
                        let outURL = panel.URL!
                        
                        // create file if it doesn't exist
                        if !NSFileManager.defaultManager().fileExistsAtPath(outURL.path!) {
                            NSFileManager.defaultManager().createFileAtPath(outURL.path!, contents: nil, attributes: nil)
                        }
                        
                        // write data to existing file
                        do {
                            let file = try NSFileHandle(forWritingToURL: panel.URL!)
                            file.writeData(outData)
                        } catch {
                            AppSingleton.alertUser("Error while creating output file", infoText: "\(error)")
                        }
                    }
                    
                } catch {
                    AppSingleton.alertUser("Error while serializing json")
                }
            } else {
                AppSingleton.alertUser("No matching data found")
            }
            
            rwc.loadingComplete()
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
        let rwc = self.view.window!.windowController! as! RefinderWindowController
        rwc.loadingComplete()
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
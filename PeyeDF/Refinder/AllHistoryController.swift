//
//  AllHistoryController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 20/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa

/// AllHistoryController 
class AllHistoryController: NSViewController, DiMeReceiverDelegate, NSTableViewDataSource, NSTableViewDelegate {
    
    var delegate: HistoryDetailDelegate?
    
    @IBOutlet weak var historyTable: NSTableView!
    var diMeFetcher: DiMeFetcher?
    
    var allHistoryTuples = [(ev: SummaryReadingEvent, ie: ScientificDocument?)]()
    
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
        let sessionId = allHistoryTuples[row].ev.sessionId
        
        // ask for output file first
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["json", "JSON"]
        panel.canSelectHiddenExtension = true
        panel.nameFieldStringValue = "\(sessionId).json"
        if panel.runModal() == NSFileHandlingPanelOKButton {
                
            let outURL = panel.URL!
            let rwc = self.view.window!.windowController! as! RefinderWindowController
            rwc.loadingStarted()
            
            diMeFetcher?.getNonSummaries(withSessionId: sessionId) {
                foundEvents in
                
                var outEyeRects = [EyeRectangle]()
                
                // generate eye rectangles
                for event in foundEvents {
                    outEyeRects.appendContentsOf(EyeRectangle.allEyeRectangles(fromReadingEvent: event, forReadingClass: .Paragraph, andSource: .SMI))
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
                        
                        
                            // create output file if it doesn't exist
                            if !NSFileManager.defaultManager().fileExistsAtPath(outURL.path!) {
                                NSFileManager.defaultManager().createFileAtPath(outURL.path!, contents: nil, attributes: nil)
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
                
                rwc.loadingComplete()
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
            if panel.runModal() == NSFileHandlingPanelOKButton {
                let inURL = panel.URL!
                let data = NSData(contentsOfURL: inURL)
                let json = JSON(data: data!)
                
                // check that loaded session id matches selection
                let fileSessionId = json["outData"]["sessionId"].stringValue
                let tableSessionId = allHistoryTuples[row].ev.sessionId
                if fileSessionId != tableSessionId {
                    AppSingleton.alertUser("Json file's id does not match table's id (selected wrong row?)")
                } else {
                    
                    var outRects = [EyeRectangle]()
                    for outR in json["outData"]["outRects"].arrayValue {
                        outRects.append(EyeRectangle(fromJson: outR))
                    }
                    self.performSegueWithIdentifier("showThresholdEditor", sender: self)
                    delegate?.setEyeRects(outRects)
                }
            }
        }
        
    }
    
    // MARK: - DiMe communication
    
    /// Ask dime to fetch data
    func reloadData() {
        diMeFetcher?.getSummaries()
    }
    
    /// Receive summaries from dime fetcher, as per protocol
    func receiveAllSummaries(tuples: [(ev: SummaryReadingEvent, ie: ScientificDocument?)]) {
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
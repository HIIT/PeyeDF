//
//  ToolController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 10/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa
import Quartz

/// Controller for the stuff within the Debug Window
class DebugController: NSViewController, NSTableViewDataSource {
    
    @IBOutlet weak var debugTable: NSTableView!
    @IBOutlet weak var titleLabel: NSTextField!
    
    private weak var pdfView: MyPDF?
    private weak var docWindow: NSWindow?
    
    var debugDescs = [String: String]()
    var debugTimes = [String: String]()
    var debugTabIdxs = [Int: String]()
    
    override func viewDidLoad() {
        debugTable.setDataSource(self)
        
    }
    
    // MARK: - Data source for debug table, including methods to check for notifications
    func numberOfRowsInTableView(aTableView: NSTableView) -> Int {
        return count(debugDescs)
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        if tableColumn!.identifier == PeyeConstants.debugTitleColName {
            return debugTabIdxs[row]
        } else if tableColumn!.identifier == PeyeConstants.debugTimeColName {
            let tit = debugTabIdxs[row]
            return debugTimes[tit!]
        } else {
            let tit = debugTabIdxs[row]
            return debugDescs[tit!]
        }
    }
    
    // MARK: - Monitor (notification) management
    
    /// Observes all notifications due to document change / navigation. Should be set once during document loading.
    /// Must call unSetMonitors when a document window closes / unloads.
    func setUpMonitors(pdfView: MyPDF, docWindow: NSWindow) {
        self.pdfView = pdfView
        self.docWindow = docWindow
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "documentChanged:", name: PeyeConstants.documentChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "zoomChanged:", name: PDFViewScaleChangedNotification, object: pdfView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "frameChanged:", name: NSViewFrameDidChangeNotification, object: pdfView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowChanged:", name: NSWindowDidMoveNotification, object: docWindow)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "occlusionChanged:", name: NSWindowDidChangeOcclusionStateNotification, object: docWindow)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "scrolled:", name:
            NSViewBoundsDidChangeNotification, object: pdfView.subviews[0].subviews[0] as! NSClipView)
    }
    
    /// Unload all notifications due to document change / navigation. Should be set once during document unloading.
    func unSetMonitors(pdfView: NSView, docWindow: NSWindow) {
        self.pdfView = nil
        self.docWindow = nil
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PeyeConstants.documentChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PDFViewScaleChangedNotification, object: pdfView)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSViewFrameDidChangeNotification, object: pdfView)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidMoveNotification, object: docWindow)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidChangeOcclusionStateNotification, object: docWindow)
        NSNotificationCenter.defaultCenter().removeObserver(self, name:
            NSViewBoundsDidChangeNotification, object: pdfView.subviews[0].subviews[0] as! NSClipView)
    }
    
    
    // MARK: - Notification callbacks
    
    @objc func occlusionChanged(notification: NSNotification) {
        let obj = notification.object as! NSWindow
        let title = "Window is visible: \(obj.occlusionState & NSWindowOcclusionState.Visible != nil)"
        let desc = "Occlusion raw: \(obj.occlusionState.rawValue), occlusion const: \(NSWindowOcclusionState.Visible.rawValue)"
        updateDesc(title, desc: desc)
    }
    
    @objc func scrolled(notification: NSNotification) {
        let obj = notification.object as! NSClipView
        updateDesc("Doc view bounds (clip view)", desc: "\(obj.documentVisibleRect)")
    }
    
    @objc func documentChanged(notification: NSNotification) {
        let obj = notification.object as! NSDocument
        updateDesc("Document changed", desc: obj.fileURL!.description)
    }
    
    @objc func zoomChanged(notification: NSNotification) {
        let obji = notification.object as! PDFView
        let desc1 = "Zoom: \(obji.scaleFactor())"
        let desc2 = "row size: \(pdfView?.pageSize().width) x \(pdfView?.pageSize().height)"
        let desc = desc1 + ", " + desc2
        updateDesc("Changed zoom (level)", desc: desc)
    }
    
    @objc func frameChanged(notification: NSNotification) {
        updateWinState()
    }
   
    @objc func windowChanged(notification: NSNotification) {
        updateWinState()
    }
    
    /// Updates (adding, if necessary) an event and its description to the list of titles and descriptions
    /// that will be shown in the debug table
    func updateDesc(title: String, desc: String) {
        if let k = debugDescs.indexForKey(title) {
            debugDescs[title] = desc
            debugTimes[title] = NSDate.shortTime()
        } else {
            debugDescs[title] = desc
            debugTimes[title] = NSDate.shortTime()
            let rowi = count(debugDescs) - 1
            debugTabIdxs[rowi] = title
        }
        
        // refresh the table view
        self.debugTable.reloadData()
    }
    
    // MARK: - Convenience
    
    /// Updates data regarding the window (frame size, location)
    private func updateWinState() {
        if let pdfView = self.pdfView {
            let desc1 = "(px) View to screen:"
            // get a rectangle representing the pdfview frame, relative to its superview and convert to the window's view
            let r1:NSRect? = pdfView.superview!.convertRect(pdfView.frame, toView: docWindow!.contentView as? NSView)
            // get screen coordinates corresponding to the rectangle got in the previous line
            let desc2 = "\(docWindow!.convertRectToScreen(r1!))"
            let desc = desc1 + ", " + desc2
            updateDesc("Changed window", desc: desc)
        }
    }

}
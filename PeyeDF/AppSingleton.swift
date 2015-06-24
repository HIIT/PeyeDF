//
//  AppSingleton.swift
//  PeyeDF
//
//  Created by Marco Filetti on 23/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa
import Quartz

/// Used to share states across the whole application. Contains:
///
/// - debugState: used to pass around debugging information
class AppSingleton {
    static let debugData = DebugData()
    static let debugWinInfo = DebugWindowInfo()
}

/// Data source for debug table
class DebugData: NSObject, NSTableViewDataSource, zoomDelegate {
    // These must match the identifier of the two column in the table view
    static let titleCol = "DebugTitleColumn"
    static let descCol = "DebugDescriptionColumn"
    
    var debugDescs: [String: String]
    var debugTabIdxs: [Int: String]
    var tabView: NSTableView?
    
    weak var pdfView: NSView?
    weak var docWindow: NSWindow?
    
    override init() {
        self.debugDescs = [String: String]()
        self.debugTabIdxs = [Int: String]()
    }
    
    func numberOfRowsInTableView(aTableView: NSTableView) -> Int {
        return count(debugDescs)
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        if tableColumn!.identifier == DebugData.titleCol {
            return debugTabIdxs[row]
        } else {
            let tit = debugTabIdxs[row]
            return debugDescs[tit!]
        }
    }
    
    func setUpMonitors(pdfView: NSView, docWindow: NSWindow) {
        self.pdfView = pdfView
        self.docWindow = docWindow
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "zoomChanged:", name: PDFViewScaleChangedNotification, object: pdfView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "trackChanged:", name: NSViewFrameDidChangeNotification, object: pdfView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "boundsChanged:", name: NSViewBoundsDidChangeNotification, object: pdfView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowChanged:", name: NSWindowDidMoveNotification, object: docWindow)
    }
    
    func updateZoom(rowSize: NSSize) {
        let hS = rowSize.height.description
        let wS = rowSize.width.description
        let desc = "Height: \(hS), Width: \(wS)"
        updateDesc("Changed zoom (row size)", desc: desc)
    }
    
    @objc func zoomChanged(notification: NSNotification) {
        let obji = notification.object as! PDFView
        let desc1 = "Zoom: \(obji.scaleFactor())"
        let desc2 = "(px) View to screen: \(docWindow?.convertRectToScreen(pdfView!.frame))"
        let desc = desc1 + ", " + desc2
        updateDesc("Changed zoom (level)", desc: desc)
    }
    
    @objc func trackChanged(notification: NSNotification) {
        let nsv = notification.object as! NSView
        let desc1 = "Track: \(nsv.frame)"
        let desc2 = "(px) View to screen: \(docWindow?.convertRectToScreen(pdfView!.frame))"
        let desc = desc1 + ", " + desc2
        updateDesc("Changed track area", desc: desc)
    }
    
    @objc func boundsChanged(notification: NSNotification) {
        let nsv = notification.object as! NSView
        let desc1 = "Bounds: \(nsv.bounds)"
        let desc2 = "(px) View to screen: \(docWindow?.convertRectToScreen(pdfView!.frame))"
        let desc = desc1 + ", " + desc2
        updateDesc("Changed bounds", desc: desc)
    }
    
    @objc func windowChanged(notification: NSNotification) {
        let nsv = notification.object as? NSWindow
        let desc1 = "(px) View to screen:"
        let desc2 = "\(nsv?.convertRectToScreen(pdfView!.frame))"
        let desc = desc1 + ", " + desc2
        updateDesc("Changed window", desc: desc)
    }
    
    /// Updates (adding, if necessary) an event and its description to the list of titles and descriptions
    /// that will be shown in the debug table
    func updateDesc(title: String, desc: String) {
        if let k = debugDescs.indexForKey(title) {
            debugDescs[title] = desc
        } else {
            debugDescs[title] = desc
            let rowi = count(debugDescs) - 1
            debugTabIdxs[rowi] = title
        }
        tabView?.reloadData()
    }
}


/// Gets all information related


/// Stores debug window instance (only one should be present in the whole app)
class DebugWindowInfo: NSObject {
    
    /// Points to the current debug window instance. Should be set only once.
    var windowController: NSWindowController?
    var debugController: DebugController?
    
    override init() {
        self.windowController = nil
        self.debugController = nil
    }
}
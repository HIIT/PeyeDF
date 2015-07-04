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
/// - debugData: used to store and update debugging information
/// - debugWinInfo: window controller and debug controller for debug info window
class AppSingleton {
    static let debugData = DebugData()
    static let debugWinInfo = DebugWindowInfo()
}

/// Data source for debug table, including methods to check for notifications
class DebugData: NSObject, NSTableViewDataSource, pageRefreshDelegate {
    
    var debugDescs: [String: String]
    var debugTimes: [String: String]
    var debugTabIdxs: [Int: String]
    
    weak var pdfView: NSView?
    weak var docWindow: NSWindow?
    
    override init() {
        self.debugDescs = [String: String]()
        self.debugTimes = [String: String]()
        self.debugTabIdxs = [Int: String]()
    }
    
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
    
    func setUpMonitors(pdfView: NSView, docWindow: NSWindow) {
        self.pdfView = pdfView
        self.docWindow = docWindow
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "zoomChanged:", name: PDFViewScaleChangedNotification, object: pdfView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "boxChanged:", name: PDFViewDisplayBoxChangedNotification, object: pdfView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "trackChanged:", name: NSViewFrameDidChangeNotification, object: pdfView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "boundsChanged:", name: NSViewBoundsDidChangeNotification, object: pdfView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowChanged:", name: NSWindowDidMoveNotification, object: docWindow)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "documentChanged:", name: PeyeConstants.documentChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "scrolled2:", name:
            NSViewBoundsDidChangeNotification, object: pdfView.subviews[0].subviews[0] as! NSClipView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "scrolled:", name:
            NSScrollViewDidEndLiveScrollNotification, object: pdfView.subviews[0] as! NSScrollView)
    }
    
    // MARK: Notification callbacks
    // note: this code is a bit messy
    
    func drawedPage(rowSize: NSSize) {
        let hS = rowSize.height.description
        let wS = rowSize.width.description
        let desc = "Height: \(hS), Width: \(wS)"
        updateDesc("Redrawn page (row size)", desc: desc)
        if let pdfw = self.pdfView as? PDFView {
            let cPage = pdfw.currentPage()
            let vg = pdfw.subviews
            let cgg: NSScrollView = vg[0] as! NSScrollView
            updateDesc("Destination", desc: "\(pdfw.currentDestination())")
            updateDesc("Bounds", desc: "\(pdfw.bounds)")
            updateDesc("Doc view bounds (pdfw)", desc: "\(pdfw.documentView().bounds)")
            updateDesc("Doc view bounds (scroll view)", desc: "\(cgg.documentVisibleRect)")
            updateDesc("Current page", desc: "\(pdfw.currentPage())")
        }
    }
    
    @objc func scrolled2(notification: NSNotification) {
        if let pdfw = self.pdfView as? PDFView { // THIS!
            let obj = notification.object as! NSClipView
            updateDesc("Doc view bounds (clip view)", desc: "\(obj.documentVisibleRect)")
        }
    }
    
    @objc func scrolled(notification: NSNotification) {
        if let pdfw = self.pdfView as? PDFView {
            let obj = notification.object as! NSScrollView
            updateDesc("Doc view bounds (scroll view, own not)", desc: "\(obj.documentVisibleRect)")
        }
    }
    
    func updateZoom(rowSize: NSSize) {
        let hS = rowSize.height.description
        let wS = rowSize.width.description
        let desc = "Height: \(hS), Width: \(wS)"
        updateDesc("Changed zoom (row size)", desc: desc)
    }
    
    @objc func documentChanged(notification: NSNotification) {
        let obj = notification.object as! NSDocument
        updateDesc("Document changed", desc: obj.fileURL!.description)
    }
    
    @objc func boxChanged(notification: NSNotification) {
        let obj = notification.object as! PDFView
        let boxi = obj.displayBox()
        let boxb = obj.currentPage().boundsForBox(boxi)
        let desc = "Bounds for box(\(boxi): \(boxb))"
        updateDesc("Box changed", desc: desc)
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
        // get a rectangle representing the pdfview frame, relative to its superview and convert to the window's view
        let r1:NSRect? = pdfView!.superview!.convertRect(pdfView!.frame, toView: nsv?.contentView as? NSView)
        // get screen coordinates corresponding to the rectangle got in the previous line
        let desc2 = "\(nsv?.convertRectToScreen(r1!))"
        let desc = desc1 + ", " + desc2
        updateDesc("Changed window", desc: desc)
    }
    
    /// Updates (adding, if necessary) an event and its description to the list of titles and descriptions
    /// that will be shown in the debug table
    func updateDesc(title: String, desc: String) {
        if let k = debugDescs.indexForKey(title) {
            debugDescs[title] = desc
            debugTimes[title] = GetCurrentTimeShort()
        } else {
            debugDescs[title] = desc
            debugTimes[title] = GetCurrentTimeShort()
            let rowi = count(debugDescs) - 1
            debugTabIdxs[rowi] = title
        }
        
        // not so clean code to refresh the table view
        AppSingleton.debugWinInfo.debugController?.debugTable.reloadData()
    }
}

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
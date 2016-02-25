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

import Foundation
import Cocoa
import Quartz

/// Controller for the stuff within the Debug Window
class DebugController: NSViewController, NSTableViewDataSource {
    
    @IBOutlet weak var debugTable: NSTableView!
    @IBOutlet weak var titleLabel: NSTextField!
    
    private weak var pdfReader: MyPDFReader?
    private weak var docWindow: NSWindow?
    
    var debugDescs = [String: String]()
    var debugTimes = [String: String]()
    var debugTabIdxs = [Int: String]()
    
    override func viewDidLoad() {
        debugTable.setDataSource(self)
        
    }
    
    // MARK: - Data source for debug table, including methods to check for notifications
    func numberOfRowsInTableView(aTableView: NSTableView) -> Int {
        return debugDescs.count
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
    func setUpMonitors(pdfReader: MyPDFReader, docWindow: NSWindow) {
        self.pdfReader = pdfReader
        self.docWindow = docWindow
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "documentChanged:", name: PeyeConstants.documentChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "zoomChanged:", name: PDFViewScaleChangedNotification, object: pdfReader)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "frameChanged:", name: NSViewFrameDidChangeNotification, object: pdfReader)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowChanged:", name: NSWindowDidMoveNotification, object: docWindow)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "occlusionChanged:", name: NSWindowDidChangeOcclusionStateNotification, object: docWindow)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "scrolled:", name:
            NSViewBoundsDidChangeNotification, object: pdfReader.subviews[0].subviews[0] as! NSClipView)
    }
    
    /// Unload all notifications due to document change / navigation. Should be set once during document unloading.
    func unSetMonitors(pdfReader: NSView, docWindow: NSWindow) {
        self.pdfReader = nil
        self.docWindow = nil
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PeyeConstants.documentChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PDFViewScaleChangedNotification, object: pdfReader)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSViewFrameDidChangeNotification, object: pdfReader)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidMoveNotification, object: docWindow)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidChangeOcclusionStateNotification, object: docWindow)
        NSNotificationCenter.defaultCenter().removeObserver(self, name:             NSViewBoundsDidChangeNotification, object: pdfReader.subviews[0].subviews[0] as! NSClipView)
    }
    
    
    // MARK: - Notification callbacks
    
    @objc func occlusionChanged(notification: NSNotification) {
        let obj = notification.object as! NSWindow
        let title = "Window is visible: \(obj.occlusionState.intersect(NSWindowOcclusionState.Visible) != [])"
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
        let obji = notification.object as! MyPDFReader
        let desc1 = "Zoom: \(obji.scaleFactor())"
        let desc = desc1
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
        if let _ = debugDescs.indexForKey(title) {
            debugDescs[title] = desc
            debugTimes[title] = NSDate.shortTime()
        } else {
            debugDescs[title] = desc
            debugTimes[title] = NSDate.shortTime()
            let rowi = debugDescs.count - 1
            debugTabIdxs[rowi] = title
        }
        
        // refresh the table view
        self.debugTable.reloadData()
    }
    
    // MARK: - Convenience
    
    /// Updates data regarding the window (frame size, location)
    private func updateWinState() {
        if let pdfReader = self.pdfReader {
            let desc1 = "(px) View to screen:"
            // get a rectangle representing the pdfReader frame, relative to its superview and convert to the window's view
            let r1:NSRect? = pdfReader.superview!.convertRect(pdfReader.frame, toView: docWindow!.contentView)
            // get screen coordinates corresponding to the rectangle got in the previous line
            let desc2 = "\(docWindow!.convertRectToScreen(r1!))"
            let desc = desc1 + ", " + desc2
            updateDesc("Changed window", desc: desc)
        }
    }

}
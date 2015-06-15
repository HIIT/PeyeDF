//
//  ToolController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 10/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa
import Quartz.PDFKit.PDFView

class ToolController: NSViewController, zoomDelegate {
    weak var pdfView: NSView?
    weak var mainWin: NSWindow?

    func setUpControllers() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "zoomChanged:", name: PDFViewScaleChangedNotification, object: pdfView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "trackChanged:", name: NSViewFrameDidChangeNotification, object: pdfView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "boundsChanged:", name: NSViewBoundsDidChangeNotification, object: pdfView)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowChanged:", name: NSWindowDidMoveNotification, object: mainWin!)
    }
    
    @IBOutlet weak var zoomLab: NSTextField!
    @IBOutlet weak var zoomLab2: NSTextField!
    @IBOutlet weak var trackALabel: NSTextField!
    @IBOutlet weak var boundsLabel: NSTextField!
    @IBOutlet weak var winLabel: NSTextField!
    
    func updateZoom(rowSize: NSSize) {
        let hS = rowSize.height.description
        let wS = rowSize.width.description
        zoomLab.stringValue = "Height: \(hS), Width: \(wS)"
    }
    
    @objc func zoomChanged(notification: NSNotification) {
        let obji = notification.object as! PDFView
        zoomLab2.stringValue = "Zoom: \(obji.scaleFactor())"
        winLabel.stringValue = "(px) View to screen: \(mainWin?.convertRectToScreen(pdfView!.frame))"
    }
    
    @objc func trackChanged(notification: NSNotification) {
        let nsv = notification.object as! NSView
        trackALabel.stringValue = "Track: \(nsv.frame)"
        winLabel.stringValue = "(px) View to screen: \(mainWin?.convertRectToScreen(pdfView!.frame))"
    }
    
    @objc func boundsChanged(notification: NSNotification) {
        let nsv = notification.object as! NSView
        boundsLabel.stringValue = "Bounds: \(nsv.bounds)"
        winLabel.stringValue = "(px) View to screen: \(mainWin?.convertRectToScreen(pdfView!.frame))"
    }
    
    @objc func windowChanged(notification: NSNotification) {
        let nsv = notification.object as? NSWindow
        winLabel.stringValue = "(px) View to screen: \(nsv?.convertRectToScreen(pdfView!.frame))"
    }
}
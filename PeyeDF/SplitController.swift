//
//  SplitController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 10/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa

class SplitController: NSSplitViewController {
    weak var myPDFController: PDFController?
    var debugController: DebugController?
    var debugWindowController: NSWindowController?
    var debugWindow: NSWindow?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        myPDFController = self.childViewControllers[0] as? PDFController
        
        debugWindowController = self.storyboard?.instantiateControllerWithIdentifier("DebugWindow") as? NSWindowController
        debugWindowController?.showWindow(self)
        debugWindow = debugWindowController?.window
        debugController = debugWindowController?.contentViewController as? DebugController
        
        
        myPDFController?.myPDF.delegateZoom = debugController
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        debugController?.pdfView = myPDFController!.myPDF as NSView
        debugController?.mainWin = self.view.window
        debugController?.setUpControllers()
    }

}
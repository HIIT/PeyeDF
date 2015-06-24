//
//  DocumentSplitController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 10/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa

/// The Document split controller contains a PDF preview (left side, index 0) and the PDFView (right side, index 1)
class DocumentSplitController: NSSplitViewController {
    weak var myPDFController: PDFController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        myPDFController = self.childViewControllers[1] as? PDFController
        
        myPDFController?.myPDF.delegateZoom = AppSingleton.debugData
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        AppSingleton.debugData.setUpMonitors(myPDFController!.myPDF, docWindow: self.view.window!)
        // TODO: This is just a stub, remove later
        let tw: NSSplitView = self.splitView as NSSplitView
        tw.setPosition(CGFloat(250), ofDividerAtIndex: 0)
    }

}
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
    weak var myPDFController: MyPDFController?
    weak var myToolController: ToolController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        myPDFController = self.childViewControllers[0] as? MyPDFController
        myToolController = self.childViewControllers[1] as? ToolController
        
        myPDFController?.myPDF.delegateZoom = myToolController
    }
    
    override func viewDidAppear() {
        println(self.view.window!)
        myToolController?.pdfView = myPDFController!.myPDF as NSView
        myToolController?.mainWin = self.view.window
        myToolController?.setUpControllers()
    }

}
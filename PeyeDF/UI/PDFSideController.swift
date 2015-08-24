//
//  ViewController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 10/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Cocoa

/// Controller for the PDF-side Document split view
class PDFSideController: NSViewController {
    
    @IBOutlet weak var myPDF: MyPDF!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }

}


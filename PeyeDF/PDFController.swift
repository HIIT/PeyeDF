//
//  ViewController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 10/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Cocoa

class PDFController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate:AppDelegate = NSApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.pdfController = self
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }


    @IBOutlet weak var testLab: NSTextField!
    @IBOutlet weak var myPDF: MyPDF!
}


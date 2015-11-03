//
//  WaitViewController.swift
//  DateTableTest
//
//  Created by Marco Filetti on 19/10/2015.
//  Copyright © 2015 mf. All rights reserved.
//

import Cocoa

class WaitViewController: NSViewController {
    
    var someText = "Please wait..."

    @IBOutlet weak var progBar: NSProgressIndicator!
    
    @IBOutlet weak var progLab: NSTextField!
    
    override func viewWillAppear() {
        super.viewWillAppear()
        progLab.stringValue = someText
        progBar.usesThreadedAnimation = true
        progBar.startAnimation(self)
    }
}

//
//  ViewController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 10/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Cocoa

/// Protocol for allowing / disallowing double and triple click recognizers
protocol ClickRecognizerDelegate {
    
    /// Set the enabled state of the recognizer to the given value
    func setRecognizersTo(enabled: Bool)
    
    /// Check if recognizers are enabled
    func getRecognizersState() -> Bool
}

/// Controller for the PDF-side Document split view
class PDFSideController: NSViewController, ClickRecognizerDelegate {
    
    @IBOutlet weak var myPDF: MyPDF!
    @IBOutlet weak var circleOverlay: CircleOverlay!
    
    @IBOutlet weak var doubleClickRecognizer: NSClickGestureRecognizer!
    @IBOutlet weak var tripleClickRecognizer: NSClickGestureRecognizer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    /// Target for the gesture recognizer used to detect double clicks
    @IBAction func doubleClick(sender: NSClickGestureRecognizer) {
        myPDF.markAndAnnotate(sender.locationInView(myPDF), importance: Importance.Important)
    }
    
    /// Target for the gesture recognizer used to detect double clicks
    @IBAction func tripleClick(sender: NSClickGestureRecognizer) {
        myPDF.markAndAnnotate(sender.locationInView(myPDF), importance: Importance.Critical)
    }
    
    /// Set the enabled state of the recognizer to the given value
    func setRecognizersTo(enabled: Bool) {
        doubleClickRecognizer.enabled = enabled
        tripleClickRecognizer.enabled = enabled
    }
    
    /// Check if recognizers are enabled
    func getRecognizersState() -> Bool {
        return doubleClickRecognizer.enabled && tripleClickRecognizer.enabled
    }
}


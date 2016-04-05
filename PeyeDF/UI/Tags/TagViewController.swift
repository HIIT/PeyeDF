//
//  ViewController.swift
//  TagStack
//
//  Created by Marco Filetti on 26/02/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Cocoa

class TagViewController: NSViewController {

    @IBOutlet weak var stackView: AnimatedStack!
    var count = 0
    @IBOutlet weak var textField: NSTextField!
    var mydel = TagFieldDelegate()
    var isCompleting = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        textField.delegate = mydel
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(textChanged(_:)), name: NSControlTextDidChangeNotification, object: textField)
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func deletePress(sender: AnyObject) {
        if let but = sender as? NSButton {
            but.enabled = false  // must disable button to prevent clicking again
            stackView.animateViewOut(but.superview!)
        }
    }

    @IBAction func addPress(sender: NSButton) {
        let newTag = textField.stringValue.trimmed()
            if newTag.characters.count > 0 {
            var objs: NSArray?  // temporary store for items in tagview
            NSBundle.mainBundle().loadNibNamed("TagView", owner: nil, topLevelObjects: &objs)
            if let objs = objs {
                for obj in objs {
                    if let view = obj as? NSView {
                        stackView.animateViewIn(view)
                        for subview in view.subviews {
                            if let but = subview as? NSButton {
                                but.tag = count
                            }
                            if let lab = subview as? NSTextField {
                                lab.stringValue = newTag
                            }
                        }
                        count += 1
                    }
                }
            }
        }
        textField.stringValue = ""
    }
    
    @objc func textChanged(notification: NSNotification) {
        let fieldEditor = notification.userInfo!["NSFieldEditor"]!
        if !isCompleting {
            isCompleting = true
            fieldEditor.complete(nil)
            isCompleting = false
        }
    }
}


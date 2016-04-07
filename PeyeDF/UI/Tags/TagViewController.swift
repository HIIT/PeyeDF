//
//  ViewController.swift
//  TagStack
//
//  Created by Marco Filetti on 26/02/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Cocoa

class TagViewController: NSViewController {
    
    let kInputFieldTag = 5
    let kLabelFieldTag = 10

    @IBOutlet weak var stackView: AnimatedStack!
    var count = 0
    @IBOutlet weak var inputField: NSTextField!
    @IBOutlet weak var labelField: NSTextField!
    
    var mydel = TagFieldDelegate()
    var isCompleting = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        inputField.delegate = mydel
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(textChanged(_:)), name: NSControlTextDidChangeNotification, object: inputField)
    }
    
    func setStatus(taggingDocument: Bool) {
        if taggingDocument {
            labelField.stringValue = "tagging document"
        } else {
            labelField.stringValue = "tagging text"
        }
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
        let newTag = inputField.stringValue.trimmed()
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
                            if let txt = subview as? NSTextField {
                                txt.stringValue = newTag
                            }
                        }
                        count += 1
                    }
                }
            }
        }
        inputField.stringValue = ""
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


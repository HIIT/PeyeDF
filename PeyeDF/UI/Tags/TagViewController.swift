//
//  ViewController.swift
//  TagStack
//
//  Created by Marco Filetti on 26/02/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Cocoa

/// Objects which set themselves as a tag delegate receive updates regarding tags
protocol TagDelegate {
    
    /// Tells the delegate that a tag was added
    func tagAdded(theTag: String)
    
    /// Tells the delegate that a tag was removed
    func tagRemoved(theTag: String)
}

class TagViewController: NSViewController {
    
    let kInputFieldTag = 5
    let kLabelFieldTag = 10

    @IBOutlet weak var stackView: AnimatedStack!
    @IBOutlet weak var inputField: NSTextField!
    @IBOutlet weak var labelField: NSTextField!
    
    var mydel = TagFieldDelegate()
    private var isCompleting = false
    private var count = 0
    
    var delegate: TagDelegate?
    
    /// Returns all tags currently displayed in the view
    private(set) var representedTags = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        inputField.delegate = mydel
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(textChanged(_:)), name: NSControlTextDidChangeNotification, object: inputField)
    }
    
    /// Resets the managed stackview and replaces it with a new list of tags (in order).
    /// Does not tell delegate about this operation.
    func setTags(tags: [String]) {
        stackView.removeAllViews()
        self.representedTags = tags
        for tag in tags {
            var objs: NSArray?  // temporary store for items in tagview
            NSBundle.mainBundle().loadNibNamed("TagView", owner: nil, topLevelObjects: &objs)
            if let objs = objs {
                for obj in objs {
                    if let view = obj as? NSView {
                        stackView.addView(view, inGravity: .Top)
                        for subview in view.subviews {
                            if let but = subview as? NSButton {
                                but.tag = count
                            }
                            if let txt = subview as? NSTextField {
                                txt.stringValue = tag
                            }
                        }
                        count += 1
                    }
                }
            }
        }
    }
    
    func setStatus(taggingDocument: Bool) {
        if taggingDocument {
            labelField.stringValue = "tagging document"
        } else {
            labelField.stringValue = "tagging text"
        }
    }

    /// Deletes a tag, and tells the delegate about it.
    @IBAction func deletePress(sender: AnyObject) {
        if let but = sender as? NSButton {
            but.enabled = false  // must disable button to prevent clicking again
            for view in but.superview!.subviews {
                if let txt = view as? NSTextField {
                    delegate?.tagRemoved(txt.stringValue)
                    self.representedTags.removeAtIndex(self.representedTags.indexOf(txt.stringValue)!)
                }
            }
            stackView.animateViewOut(but.superview!)
        }
    }

    @IBAction func addPress(sender: NSButton) {
        let newTag = inputField.stringValue.trimmed()
        if newTag.characters.count > 0 && !representedTags.contains(newTag) {
            representedTags.append(newTag)
            delegate?.tagAdded(newTag)
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


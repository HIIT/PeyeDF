//
// Copyright (c) 2015 Aalto University
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

import Cocoa

// MARK: - Protocol

/// Objects which set themselves as a tag delegate receive updates regarding tags
protocol TagDelegate: class {
    
    /// Tells the delegate that a tag was added
    func tagAdded(_ theTag: String)
    
    /// Tells the delegate that a tag was removed
    func tagRemoved(_ theTag: String)
    
    /// Asks the delegate whether we are adding a reading tag
    func isNextTagReading() -> Bool
    
    /// Tells the delegate that the "text" button was pressed
    func tagInfo(_ theTag: String)
}

// MARK: - View Controller

class TagViewController: NSViewController {
    
    let kInputFieldTag = 5
    let kLabelFieldTag = 10
    let kLookupButId = "lookupButton"  // make sure this is the same in IB

    @IBOutlet weak var stackView: AnimatedStack!
    @IBOutlet weak var inputField: NSTextField!
    @IBOutlet weak var labelField: NSTextField!
    
    var mydel = TagFieldDelegate()
    fileprivate var isCompleting = false
    fileprivate var count = 0
    
    weak var tagDelegate: TagDelegate?
    
    /// Returns all tags currently displayed in the view
    fileprivate(set) var representedTags = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        inputField.delegate = mydel
        NotificationCenter.default.addObserver(self, selector: #selector(textChanged(_:)), name: NSNotification.Name.NSControlTextDidChange, object: inputField)
    }
    
    // MARK: - External
    
    /// Resets the managed stackview and replaces it with a new list of tags (in order).
    /// Does not tell delegate about this operation.
    func setTags(_ tags: [Tag]) {
        stackView.removeAllViews()
        self.representedTags = tags.map({$0.text})
        for tag in tags {
            var objs: NSArray? = NSArray() // temporary store for items in tagview
            Bundle.main.loadNibNamed("TagView", owner: nil, topLevelObjects: &objs!)
            if let objs = objs {
                for obj in objs {
                    if let view = obj as? NSView {
                        stackView.addView(view, in: .top)
                        for subview in view.subviews {
                            if let but = subview as? NSButton {
                                but.tag = count
                                // show lookup button only if tag is a readingtag
                                if let butI = but.identifier , butI == kLookupButId {
                                    if type(of: tag) == ReadingTag.self {
                                        but.isHidden = false
                                    } else {
                                        but.isHidden = true
                                    }
                                }
                            }
                            if let txt = subview as? NSTextField {
                                txt.stringValue = tag.text
                            }
                        }
                        count += 1
                    }
                }
            }
        }
    }
    
    /// Sets the label text
    func setStatus(_ taggingDocument: Bool) {
        if taggingDocument {
            labelField.stringValue = "tagging document"
        } else {
            labelField.stringValue = "tagging text"
        }
    }
    
    // MARK: - Event receipt
    
    /// Tells the delegate that we want info for a spefic tag and closes its own window.
    @IBAction func textPress(_ sender: AnyObject) {
        if let but = sender as? NSButton {
            for view in but.superview!.subviews {
                if let txt = view as? NSTextField {
                    tagDelegate?.tagInfo(txt.stringValue)
                    self.view.window?.performClose(self)
                }
            }
        }
    }

    /// Deletes a tag, and tells the delegate about it.
    @IBAction func deletePress(_ sender: AnyObject) {
        if let but = sender as? NSButton {
            but.isEnabled = false  // must disable button to prevent clicking again
            for view in but.superview!.subviews {
                if let txt = view as? NSTextField {
                    tagDelegate?.tagRemoved(txt.stringValue)
                    self.representedTags.remove(at: self.representedTags.index(of: txt.stringValue)!)
                }
            }
            stackView.animateViewOut(but.superview!)
        }
    }

    /// Adds a tag, and tells the delegate about it.
    @IBAction func addPress(_ sender: NSButton) {
        let newTag = inputField.stringValue.trimmed()
        if newTag.characters.count > 0 && !representedTags.contains(newTag) {
            representedTags.append(newTag)
            tagDelegate?.tagAdded(newTag)
            AppSingleton.updateRecentTags(newTag)
            var objs: NSArray? = NSArray() // temporary store for items in tagview
            Bundle.main.loadNibNamed("TagView", owner: nil, topLevelObjects: &objs!)
            if let objs = objs {
                for obj in objs {
                    if let view = obj as? NSView {
                        stackView.animateViewIn(view)
                        for subview in view.subviews {
                            if let but = subview as? NSButton {
                                but.tag = count
                                if let butI = but.identifier , butI == kLookupButId {
                                    if tagDelegate!.isNextTagReading() {
                                        but.isHidden = false
                                    }
                                }
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
    
    // MARK: - Notification callbacks
    
    /// Notification callback for changed text (for auto-completion)
    @objc func textChanged(_ notification: Notification) {
        let fieldEditor = (notification as NSNotification).userInfo!["NSFieldEditor"]!
        if !isCompleting {
            isCompleting = true
            (fieldEditor as AnyObject).complete(nil)
            isCompleting = false
        }
    }
}


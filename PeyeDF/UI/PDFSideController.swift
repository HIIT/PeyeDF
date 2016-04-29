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

/// Protocol for allowing / disallowing double and triple click recognizers
protocol ClickRecognizerDelegate: class {
    
    /// Set the enabled state of the recognizer to the given value
    func setRecognizersTo(enabled: Bool)
    
    /// Check if recognizers are enabled
    func getRecognizersState() -> Bool
}

/// Controller for the PDF-side Document split view
class PDFSideController: NSViewController, ClickRecognizerDelegate, NSGestureRecognizerDelegate {
    
    @IBOutlet weak var pdfReader: MyPDFReader!
    @IBOutlet weak var overlay: MyOverlay!
    
    @IBOutlet weak var doubleClickRecognizer: NSClickGestureRecognizer!
    @IBOutlet weak var tripleClickRecognizer: NSClickGestureRecognizer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        overlay.otherView = pdfReader  // tell circleOverlay to be transparent
        doubleClickRecognizer.delegate = self  // to prevent immediate double click recognition
    }
    
    /// Target for the gesture recognizer used to detect double clicks
    @IBAction func doubleClick(sender: NSClickGestureRecognizer) {
        pdfReader.markAndAnnotate(sender.locationInView(pdfReader), importance: ReadingClass.Interesting)
    }
    
    /// Target for the gesture recognizer used to detect double clicks
    @IBAction func tripleClick(sender: NSClickGestureRecognizer) {
        pdfReader.markAndAnnotate(sender.locationInView(pdfReader), importance: ReadingClass.Critical)
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
    
    // MARK: Delegation
    
    /// Overriding this method to prevent double clicks from registering immediately
    func gestureRecognizer(gestureRecognizer: NSGestureRecognizer, shouldRequireFailureOfGestureRecognizer otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        if otherGestureRecognizer === tripleClickRecognizer {
            return true
        } else {
            return false
        }
    }
}


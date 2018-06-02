//
// Copyright (c) 2018 University of Helsinki, Aalto University
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

/// Protocol for allowing / disallowing double and triple click recognizers and
/// display of peer (not own) fixations
protocol PDFReaderDelegate: class {
    
    /// Set the enabled state of the recognizer to the given value
    func setRecognizersTo(_ enabled: Bool)
    
    /// Check if recognizers are enabled
    func getRecognizersState() -> Bool
    
    /// Receive a peer fixation and animate accordingly
    func displayPeerFixation(pointInView: CGPoint)
    
    /// Clear fixation indicators
    func clearFixations()
}

/// Controller for the PDF-side Document split view
class PDFSideController: NSViewController, PDFReaderDelegate, NSGestureRecognizerDelegate {
    
    @IBOutlet weak var pdfReader: PDFReader!
    @IBOutlet weak var overlay: MyOverlay!
    
    @IBOutlet weak var doubleClickRecognizer: NSClickGestureRecognizer!
    @IBOutlet weak var tripleClickRecognizer: NSClickGestureRecognizer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        overlay.readerView = pdfReader  // tell Overlay to be transparent
        doubleClickRecognizer.delegate = self  // to prevent immediate double click recognition
        
        NotificationCenter.default.addObserver(self, selector: #selector(fixationReceived(notification:)), name: PeyeConstants.fixationWithinDocNotification, object: pdfReader)
    }
    
    /// Target for the gesture recognizer used to detect double clicks
    @IBAction func doubleClick(_ sender: NSClickGestureRecognizer) {
        pdfReader.quickMarkAndAnnotate(sender.location(in: pdfReader), importance: ReadingClass.medium)
    }
    
    /// Target for the gesture recognizer used to detect double clicks
    @IBAction func tripleClick(_ sender: NSClickGestureRecognizer) {
        pdfReader.quickMarkAndAnnotate(sender.location(in: pdfReader), importance: ReadingClass.high)
    }
    
    // MARK: - Protocol implementation
    
    /// Set the enabled state of the recognizer to the given value
    func setRecognizersTo(_ enabled: Bool) {
        doubleClickRecognizer.isEnabled = enabled
        tripleClickRecognizer.isEnabled = enabled
    }
    
    /// Check if recognizers are enabled
    func getRecognizersState() -> Bool {
        return doubleClickRecognizer.isEnabled && tripleClickRecognizer.isEnabled
    }
    
    /// Receive peer fixation and animate accordingly
    func displayPeerFixation(pointInView: CGPoint) {
        overlay.moveFix(toPoint: pointInView, isTheirs: true)
    }
    
    /// Clear fixation indicators
    func clearFixations() {
        overlay.clearFixations()
    }
    
    // MARK: - Delegation
    
    /// Overriding this method to prevent double clicks from registering immediately
    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        if otherGestureRecognizer === tripleClickRecognizer {
            return true
        } else {
            return false
        }
    }
    
    // MARK: - Notification callbacks
    @objc func fixationReceived(notification: NSNotification) {
        guard notification.name == PeyeConstants.fixationWithinDocNotification, let uInfo = notification.userInfo else {
            return
        }
        
        let xpos = uInfo["xpos"] as! CGFloat
        let ypos = uInfo["ypos"] as! CGFloat
        let point = CGPoint(x: xpos, y: ypos)
        overlay.moveFix(toPoint: point)
    }
}


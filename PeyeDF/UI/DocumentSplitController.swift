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

import Foundation
import Cocoa

/// A protocol that allows a delegate to notify that the side view was collapsed/uncollapsed.
@objc protocol SideCollapseToggleDelegate {
    func sideCollapseAction(wasCollapsed: Bool)
}

/// The Document split controller contains a PDF preview (left side, index 0) and the PDFView (right side, index 1)
class DocumentSplitController: NSSplitViewController {
    
    weak var myPDFSideController: PDFSideController?
    weak var myThumbController: ThumbSideController?
    weak var sideCollapseDelegate: SideCollapseToggleDelegate?
    
    // MARK: - Initialisation
    
    override func viewDidLoad() {
        super.viewDidLoad()
        myThumbController = self.childViewControllers[0] as? ThumbSideController
        myPDFSideController = self.childViewControllers[1] as? PDFSideController
    }
    
    // MARK: - Thumbnail side collapse / uncollapse

    func toggleThumbSide() {
        let tw: NSSplitView = self.splitView as NSSplitView
        let collState = checkCollapseStatus(tw)
        // let the delegate know what happened
        sideCollapseDelegate?.sideCollapseAction(collState)
        if collState {
            tw.setPosition(PeyeConstants.defaultThumbSideViewWidth, ofDividerAtIndex: 0)
        } else {
            tw.setPosition(0, ofDividerAtIndex: 0)
        }
    }
    
    /// Overriding this method to include delegate communication
    override func splitView(splitView: NSSplitView, shouldCollapseSubview subview: NSView, forDoubleClickOnDividerAtIndex dividerIndex: Int) -> Bool {
        sideCollapseDelegate?.sideCollapseAction(true)
        return super.splitView(splitView, shouldCollapseSubview: subview, forDoubleClickOnDividerAtIndex: dividerIndex)
    }
    
    /// Overriding this method to include delegate communication
    override func splitViewDidResizeSubviews(notification: NSNotification) {
        let tw = notification.object as! NSSplitView
        let collState = checkCollapseStatus(tw)
        sideCollapseDelegate?.sideCollapseAction(collState)
    }
    
    /// Convenience function to check if the splitview is collapsed or not
    ///
    /// - parameter splitView: The splitview containing the thumbs (index 0) and document (index 1)
    /// - returns: false if not collapsed (or couldn't be found) true if collapsed
    func checkCollapseStatus(splitView: NSSplitView) -> Bool {
        let subw = splitView.subviews[0]
        if splitView.isSubviewCollapsed(subw) || subw.visibleRect.width < PeyeConstants.minThumbSideViewWidth {
            return true
        } else {
            return false
        }
    }
}
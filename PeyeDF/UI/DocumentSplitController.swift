//
//  DocumentSplitController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 10/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

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
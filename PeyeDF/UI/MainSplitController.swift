//
//  MainSplitController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 10/09/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Cocoa


/// A protocol that allows a delegate to notify that the search panel was collapsed/uncollapsed.
@objc protocol SearchPanelCollapseDelegate {
    func searchCollapseAction(wasCollapsed: Bool)
}

/// The main split controller contains the search panel (top) and two other split views (bottom)
class MainSplitController: NSSplitViewController {
    
    weak var searchCollapseDelegate: SearchPanelCollapseDelegate?
    weak var searchPanelController: SearchPanelController?
    
    // MARK: - Initialisation
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchPanelController = self.childViewControllers[0] as? SearchPanelController
        
    }
    
    // MARK: - Search panel collapse / uncollapse
    
    func openSearchPanel() {
        let tw: NSSplitView = self.splitView as NSSplitView
        let collState = checkCollapseStatus(tw)
        if collState {
            tw.setPosition(PeyeConstants.defaultSearchPanelViewHeight, ofDividerAtIndex: 0)
        }
        // let the delegate know what happened
        searchCollapseDelegate?.searchCollapseAction(collState)
        searchPanelController?.makeSearchFieldFirstResponderWithDelay()
    }
    
    func toggleSearchPanel() {
        let tw: NSSplitView = self.splitView as NSSplitView
        let collState = checkCollapseStatus(tw)
        // let the delegate know what happened
        searchCollapseDelegate?.searchCollapseAction(collState)
        if collState {
            tw.setPosition(PeyeConstants.defaultSearchPanelViewHeight, ofDividerAtIndex: 0)
            searchPanelController?.makeSearchFieldFirstResponderWithDelay()
        } else {
            tw.setPosition(0, ofDividerAtIndex: 0)
        }
    }
    
    
    /// Overriding this method to include delegate communication
    override func splitView(splitView: NSSplitView, shouldCollapseSubview subview: NSView, forDoubleClickOnDividerAtIndex dividerIndex: Int) -> Bool {
        searchCollapseDelegate?.searchCollapseAction(true)
        return super.splitView(splitView, shouldCollapseSubview: subview, forDoubleClickOnDividerAtIndex: dividerIndex)
    }
    
    /// Overriding this method to include delegate communication
    override func splitViewDidResizeSubviews(notification: NSNotification) {
        let tw = notification.object as! NSSplitView
        let collState = checkCollapseStatus(tw)
        searchCollapseDelegate?.searchCollapseAction(collState)
    }
    
    /// Convenience function to check if the splitview is collapsed or not
    ///
    /// :param: splitView The splitview containing the search (index 0) and doc split (index 1)
    /// :returns: false if not collapsed (or couldn't be found) true if collapsed
    func checkCollapseStatus(splitView: NSSplitView) -> Bool {
        if let subw = splitView.subviews[0] as? NSView {
            if splitView.isSubviewCollapsed(subw) || subw.visibleRect.height < PeyeConstants.minSearchPanelViewHeight {
                return true
            } else {
                return false
            }
        }
        return false
    }
}
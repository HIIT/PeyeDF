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


/// A protocol that allows a delegate to notify that the search panel was collapsed/uncollapsed.
@objc protocol SearchPanelCollapseDelegate: class {
    func searchCollapseAction(_ wasCollapsed: Bool)
}

/// The main split controller contains the search panel (top) and two other split views (bottom)
class MainSplitController: NSSplitViewController {
    
    weak var searchCollapseDelegate: SearchPanelCollapseDelegate?
    weak var searchPanelController: SearchPanelController?
    weak var searchProvider: SearchProvider?
    
    // MARK: - Initialisation
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchPanelController = self.childViewControllers[0] as? SearchPanelController
        searchProvider = searchPanelController
    }
    
    // MARK: - Search panel collapse / uncollapse
    
    func openSearchPanel() {
        let tw: NSSplitView = self.splitView as NSSplitView
        let collState = checkCollapseStatus(tw)
        if collState {
            tw.setPosition(PeyeConstants.defaultSearchPanelViewHeight, ofDividerAt: 0)
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
            tw.subviews[0].isHidden = false
            tw.setPosition(PeyeConstants.defaultSearchPanelViewHeight, ofDividerAt: 0)
            searchPanelController?.makeSearchFieldFirstResponderWithDelay()
        } else {
            tw.setPosition(0, ofDividerAt: 0)
            tw.subviews[0].isHidden = true
        }
        tw.adjustSubviews()
    }
    
    
    /// Overriding this method to include delegate communication
    override func splitView(_ splitView: NSSplitView, shouldCollapseSubview subview: NSView, forDoubleClickOnDividerAt dividerIndex: Int) -> Bool {
        searchCollapseDelegate?.searchCollapseAction(true)
        return super.splitView(splitView, shouldCollapseSubview: subview, forDoubleClickOnDividerAt: dividerIndex)
    }
    
    /// Overriding this method to include delegate communication
    override func splitViewDidResizeSubviews(_ notification: Notification) {
        let tw = notification.object as! NSSplitView
        let collState = checkCollapseStatus(tw)
        searchCollapseDelegate?.searchCollapseAction(collState)
    }
    
    /// Convenience function to check if the splitview is collapsed or not
    ///
    /// - parameter splitView: The splitview containing the search (index 0) and doc split (index 1)
    /// - returns: false if not collapsed (or couldn't be found) true if collapsed
    func checkCollapseStatus(_ splitView: NSSplitView) -> Bool {
        let subw = splitView.subviews[0]
        if splitView.isSubviewCollapsed(subw) || subw.visibleRect.height < PeyeConstants.minSearchPanelViewHeight {
            return true
        } else {
            return false
        }
    }
}

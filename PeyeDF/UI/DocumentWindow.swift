//
//  DocumentWindow.swift
//  PeyeDF
//
//  Created by Marco Filetti on 16/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Cocoa

/// The class used by the window which displays the document (and all subviews).
/// Also contain static function to keep window in a certain position because of eye tracking.
class DocumentWindow: NSWindow {
    
    /// how much of the whole screen should be covered, at most,
    /// so that eye tracker accuracy is maximised (so that
    /// window does not cover corners or margins).
    static let kScreenCoverProportion: CGFloat = 6/7
    
    /// returns the rectangle in which the window should be contrained
    static func getConstrainingRect(forScreen screen: NSScreen) -> NSRect {
    
        var shrankScreenRect = screen.frame
        
        // push origin right by the desired amount and shrink width by twice that
        let hpoints = screen.frame.width / screen.backingScaleFactor
        let horizontalOffset = hpoints - hpoints * kScreenCoverProportion
        shrankScreenRect.origin.x += horizontalOffset
        shrankScreenRect.size.width -= horizontalOffset * 2
        
        // push origin up by etc etc (same as above)
        let vpoints = screen.frame.height / screen.backingScaleFactor
        let verticalOffset = vpoints - vpoints * kScreenCoverProportion
        shrankScreenRect.origin.y += verticalOffset
        shrankScreenRect.size.height -= verticalOffset * 2
        
        return shrankScreenRect
    }
    
    /// If MIDAS is being used, contrains the window to cover
    override func constrainFrameRect(frameRect: NSRect, toScreen screen: NSScreen?) -> NSRect {
        if let screen = screen {
            if MidasManager.sharedInstance.midasAvailable {
                let shrankScreenRect = DocumentWindow.getConstrainingRect(forScreen: screen)
                // intersect the computed shrank screen with the desired new rect, and return that
                return frameRect.intersect(shrankScreenRect)
            } else {
                return super.constrainFrameRect(frameRect, toScreen: screen)
            }
        } else {
            return super.constrainFrameRect(frameRect, toScreen: screen)
        }
    }
    
}

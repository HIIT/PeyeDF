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
    
    /// If an eye tracker is being used, contrains the window to cover
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        if let screen = screen {
            if AppSingleton.EyeTracker?.available ?? false {
                let shrankScreenRect = DocumentWindow.getConstrainingRect(forScreen: screen)
                // intersect the computed shrank screen with the desired new rect, and return that
                return frameRect.intersection(shrankScreenRect)
            } else {
                return super.constrainFrameRect(frameRect, to: screen)
            }
        } else {
            return super.constrainFrameRect(frameRect, to: screen)
        }
    }
    
    override func close() {
        if let windowController = self.windowController as? DocumentWindowController {
            if windowController.closeToken == 0 {
                windowController.unload() {
                    super.close()
                }
            }
        } else {
            super.close()
        }
    }
    
}

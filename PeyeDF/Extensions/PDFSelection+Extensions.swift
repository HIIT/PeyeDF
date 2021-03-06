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

import Foundation
import Quartz

extension PDFSelection {
    
    /// Returns a string corresponding to all text found on the first line
    /// of this selection.
    func lineString() -> String {
        let page = pages[0] 
        let selRect = bounds(for: page)
        // point for line is 0.5 points down in both directions from top left
        let x = selRect.origin.x + 0.5
        let y = selRect.origin.y + selRect.size.height + 0.5
        let selPoint = NSPoint(x: x, y: y)
        let lineSel = page.selectionForLine(at: selPoint)
        return lineSel!.string!.trimmed()
    }
    
    /// Returns the rect corresponding to an adjacent line (previous / next line).
    /// - Parameter direction: If ≥ 0, find to the next line (downwards on page, lower y origin).
    /// If direction is negative, go to previous line (upwards on page, higher y).
    /// - Returns: The rect corresponding to the adjacent line, or nil if there is no adjacent line.
    /// - Attention: PDF Selections comparisons are not so accurate (make sure they contain
    ///   some text before using them.
    func adjacentLineRect(_ direction: CGFloat) -> NSRect? {
        let kStep: CGFloat = 0.5  // how many points we step
        let vStep: CGFloat  // repeatedly step this amount of points back / forward to find line
        
        if direction >= 0 {
            // find next line
            vStep = -kStep
        } else {
            // find previous line
            vStep = kStep
        }
        
        var foundRect: NSRect? = nil
        let page = pages[0] 
        let pageRect = page.bounds(for: PDFDisplayBox.cropBox)
        let selRect = bounds(for: page)
        let centreX = selRect.origin.x + selRect.size.width / 2.0
        let centreY = selRect.origin.y + selRect.size.height / 2.0
        var currentPoint = NSPoint(x: centreX, y: centreY)
        
        currentPoint.y += vStep
        // stop when overflowing page bounds
        while (foundRect == nil && NSPointInRect(currentPoint, pageRect)) {
            let otherSel = page.selectionForLine(at: currentPoint)
            let otherSelRect = otherSel!.bounds(for: page)
            if !selRect.intersects(otherSelRect) {
                // return first line that does not interect with this one
                foundRect = otherSelRect
            }
            currentPoint.y += vStep
        }
        
        return foundRect
    }
    
    /// Return trues if the given selection is adjacent (is on the next / previous line relative)
    /// to this selection.
    /// - Attention: PDF Selections comparisons are not so accurate (make sure they contain
    ///   some text before using them).
    func isAdjacent(toSelection otherSel: PDFSelection) -> Bool {
        let otherPage = otherSel.pages[0] 
        if self.pages[0] != otherPage {
            return false
        }
        let otherSelRect = otherSel.bounds(for: otherPage)
        if let nRect = adjacentLineRect(1) {
            if nRect.intersects(otherSelRect) {
                return true
            }
        }
        if let pRect = adjacentLineRect(-1) {
            if pRect.intersects(otherSelRect) {
                return true
            }
        }
        return false
    }
    
    /// Return true if the given rect is adjacent (is on the next / previous line relative)
    /// to this selection.
    /// - Note: Must make sure that selection and rect are on the same page before comparing them.
    func isAdjacent(toRect otherSelRect: NSRect) -> Bool {
        if let nRect = adjacentLineRect(1) {
            if nRect.intersects(otherSelRect) {
                return true
            }
        }
        if let pRect = adjacentLineRect(-1) {
            if pRect.intersects(otherSelRect) {
                return true
            }
        }
        return false
    }
    
    /// Returns true if two selections are "practically the same".
    /// Empty selections are always equal.
    func equalsTo(_ rhs: PDFSelection) -> Bool {
        if self.pages.count == 0 {
            return true
        } else if self.pages.count != rhs.pages.count {
            return false
        }
        for p in self.pages {
            let pp = p 
            if self.bounds(for: pp) != rhs.bounds(for: pp) {
                return false
            }
        }
        return true
    }
}

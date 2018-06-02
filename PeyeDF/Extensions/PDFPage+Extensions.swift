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

extension PDFPage {
    
    /// Returns true if two rects are adjacent to each other (e.g. one appears on the
    /// next previous line of the other).
    func rectsNearby(_ a: NSRect, _ b: NSRect) -> Bool {
        let horizontalMax: CGFloat = 2  // points of horizontal tolerance
        
        // true if they are vertically close and at both have at least one border matching
        // with widest lines's border
        if a.isVerticallyNear(b) {
            // union of both lines
            guard let linea = selectionForLine(at: NSPoint(x: a.midX, y: a.midY))?.bounds(for: self), let lineb = selectionForLine(at: NSPoint(x: b.midX, y: b.midY))?.bounds(for: self) else {
                return false
            }
            let widestLine = NSUnionRect(linea, lineb)
            let aWithinTolerance = abs(a.maxX - widestLine.maxX) < horizontalMax || abs(a.minX - widestLine.minX) < horizontalMax
            let bWithinTolerance = abs(b.maxX - widestLine.maxX) < horizontalMax || abs(b.minX - widestLine.minX) < horizontalMax
            if aWithinTolerance && bWithinTolerance {
                return true
            }
        }
        return false
    }
    
}

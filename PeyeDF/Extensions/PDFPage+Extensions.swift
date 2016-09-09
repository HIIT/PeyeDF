//
//  PDFPage+Extensions.swift
//  PeyeDF
//
//  Created by Marco Filetti on 12/06/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation
import Quartz

extension PDFPage {
    
    /// Returns true if two rects are adjacent to each other (e.g. one appears on the
    /// next previous line of the other).
    func rectsNearby(a: NSRect, _ b: NSRect) -> Bool {
        let horizontalMax: CGFloat = 2  // points of horizontal tolerance
        
        // true if they are vertically close and at both have at least one border matching
        // with widest lines's border
        if a.isVerticallyNear(b) {
            // union of both lines
            guard let linea = selectionForLineAtPoint(NSPoint(x: a.midX, y: a.midY))?.boundsForPage(self), let lineb = selectionForLineAtPoint(NSPoint(x: b.midX, y: b.midY))?.boundsForPage(self) else {
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

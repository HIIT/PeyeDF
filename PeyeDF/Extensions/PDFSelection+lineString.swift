//
//  PDFSelection+lineString.swift
//  PeyeDF
//
//  Created by Marco Filetti on 23/02/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation
import Quartz

extension PDFSelection {
    
    /// Returns a string corresponding to all text found on the same line
    /// as this selection.
    func lineString() -> String {
        let page = pages()[0] as! PDFPage
        let selRect = boundsForPage(page)
        let selPoint = NSPoint(x: selRect.origin.x + selRect.width / 2, y: selRect.origin.y + selRect.height / 2)
        let lineSel = page.selectionForLineAtPoint(selPoint)
        return lineSel.string().trimmed()
    }
    
}
//
//  MyPDFDetail.swift
//  PeyeDF
//
//  Created by Marco Filetti on 04/11/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Cocoa
import Quartz
import Foundation

class MyPDFDetail: MyPDFBase {

    /// Scrolls the view to the given rect on the given page index
    /// Adds a half the frame size to y to center the desired point in the view.
    func scrollToRect(var rect: NSRect, onPageIndex: Int) {
        let thePage = document().pageAtIndex(onPageIndex)
        rect.origin.y += frame.size.height / 2
        goToRect(rect, onPage: thePage)
    }
    
}

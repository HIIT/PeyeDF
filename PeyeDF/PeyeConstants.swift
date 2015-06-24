//
//  PeyeConstants.swift
//  PeyeDF
//
//  Created by Marco Filetti on 24/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

/// All constants used are put here for convenience.
class PeyeConstants {
    /// Column name for debug table. Make sure this identifier matches the table view id in the storyboard
    static let debugTitleColName = "DebugTitleColumn"
    
    /// Column name for debug table. Make sure this identifier matches the table view id in the storyboard
    static let debugDescColName = "DebugDescriptionColumn"
    
    /// Defines how large is the vertical span of columns being looked at, depending on the zoom level
    static let vSpanDenom = CGFloat(3)
}

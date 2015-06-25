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
    
    /// Name of thumbnail button down (pressed) image
    static let thumbButton_DOWN = "TB_ThumbD"
    
    /// Name of thumbnail button up (not pressed) image
    static let thumbButton_UP = "TB_ThumbU"
    
    /// Minimum size of thumbnail side view to be considered as "visible"
    static let minThumbSideViewWidth = CGFloat(20)
    
    /// Default size of thumbain side view (set when pressing button)
    static let defaultThumbSideViewWidth = CGFloat(200)
    
    /// String identifying the notification sent when a new document is opened / switched to
    static let documentChangeNotification = "hiit.PeyeDF.documentChangeNotification"
}

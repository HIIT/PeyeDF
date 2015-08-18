//
//  PeyeConstants.swift
//  PeyeDF
//
//  Created by Marco Filetti on 24/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

/// All constants used are put here for convenience.
struct PeyeConstants {
    
    // MARK: History-specific constants
    // (For DiMe)
    
    /// Amount of seconds that are needed before we start recording the current event.
    static let minReadTime: CGFloat = 5
    
    /// Amount of seconds after which we always close a reading event.
    /// (It is assumed the user went away from keyboard).
    static let maxReadTime: CGFloat = 600
    
    // MARK: Debug
    
    /// Column name for debug table. Make sure this identifier matches the table view id in the storyboard
    static let debugTitleColName = "DebugTitleColumn"
    
    /// Column name for debug table. Make sure this identifier matches the table view id in the storyboard
    static let debugDescColName = "DebugDescriptionColumn"
    
    /// Column name for debug table. Make sure this identifier matches the table view id in the storyboard
    static let debugTimeColName = "DebugTimeColumn"
    
    // MARK: Other globals
    
    /// How much space do we leave between margins of the window and text we consider visible. In points.
    static let extraMargin: CGFloat = 2
    
    /// Defines how large is the vertical span of text being looked at, depending on the zoom level
    static let vSpanDenom: CGFloat = 3
    
    /// Name of thumbnail button down (pressed) image
    static let thumbButton_DOWN = "TB_ThumbD"
    
    /// Name of thumbnail button up (not pressed) image
    static let thumbButton_UP = "TB_ThumbU"
    
    /// Minimum size of thumbnail side view to be considered as "visible"
    static let minThumbSideViewWidth: CGFloat = 20
    
    /// Default size of thumbnail side view (set when pressing button)
    static let defaultThumbSideViewWidth: CGFloat = 200
    
    // MARK: Notifications
    
    /// String identifying the notification sent when a new document is opened / switched to
    static let occlusionChangeNotification = "hiit.PeyeDF.occlusionChangeNotification"
    
    /// String identifying the notification sent when a new document is opened / switched to
    static let documentChangeNotification = "hiit.PeyeDF.documentChangeNotification"
    
}

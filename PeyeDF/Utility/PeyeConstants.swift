//
//  PeyeConstants.swift
//  PeyeDF
//
//  Created by Marco Filetti on 24/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa

/// All constants used are put here for convenience.
struct PeyeConstants {
    
    // MARK: - History-specific constants
    // (For DiMe)
    
    /// URL of the DiMe server (bound in the preferences window)
    static let prefServerURL = "serverinfo.url"
    
    /// Username of the DiMe server (bound in the preferences window)
    static let prefServerUserName = "serverinfo.userName"
    
    /// Password of the DiMe server (bound in the preferences window)
    static let prefServerPassword = "serverinfo.password"
    
    /// Wheter we want to push an event at every window focus event (bound in the preferences window)
    static let prefSendEventOnFocusSwitch = "preferences.sendEventOnFocusSwitch"
    
    /// Amount of seconds that are needed before we start recording the current event.
    static let minReadTime: CGFloat = 5
    
    /// Amount of seconds after which we always close a reading event.
    /// (It is assumed the user went away from keyboard).
    static let maxReadTime: CGFloat = 600
    
    /// Date formatter shared in DiMe submissions (uses date format below)
    static let diMeDateFormatter = PeyeConstants.makeDateFormatter()
    
    /// Date format used for DiMe submission
    static let diMeDateFormat = "Y'-'MM'-'d'T'HH':'mm':'ssZ"
    
    // MARK: - Debug
    
    /// Column name for debug table. Make sure this identifier matches the table view id in the storyboard
    static let debugTitleColName = "DebugTitleColumn"
    
    /// Column name for debug table. Make sure this identifier matches the table view id in the storyboard
    static let debugDescColName = "DebugDescriptionColumn"
    
    /// Column name for debug table. Make sure this identifier matches the table view id in the storyboard
    static let debugTimeColName = "DebugTimeColumn"
    
    // MARK: - Rectangle reading classes
    
    /// Unspecified reading class
    static let CLASS_UNSET = 0
    
    /// Class for viewport (simple read without eye tracking) text
    static let CLASS_VIEWPORT = 10
    
    /// Class for eye tracking read text.
    static let CLASS_READ = 20
    
    /// Class for eye tracking "interesting" rectangles.
    static let CLASS_INTERESTING = 25
    
    /// Class for eye tracking "critical" rectangles.
    static let CLASS_CRITICAL = 30
    
    // MARK: - Annotations
    
    /// Space between the "selection" (seen paragraph) rectangle and its line (in page points)
    static let annotationLineDistance: CGFloat = 7
    
    /// Default color of the read annotation lines
    static let annotationColourRead: NSColor = NSColor(red: 0.24, green: 0.74, blue: 0.97, alpha: 0.75)
    
    /// Default color of the "interesting" annotation lines
    static let annotationColourInteresting: NSColor = NSColor(red: 0.92, green: 0.71, blue: 0.43, alpha: 0.75)
    
    /// Default color of the "critical" annotation lines
    static let annotationColourCritical: NSColor = NSColor(red: 0.99, green: 0.24, blue: 0.26, alpha: 0.75)
    
    /// Array of all annotation colours, in ascending order of importance
    static let annotationAllColours = [PeyeConstants.annotationColourRead,
                                       PeyeConstants.annotationColourInteresting,
                                       PeyeConstants.annotationColourCritical]
    
    // MARK: - Other globals
    
    /// When comparing rectangles, they are at the same horizontal positions if they are separated by less than this amount of points.
    static let rectHorizontalTolerance: CGFloat = 2.0
    
    /// How much space do we leave between margins of the window and text we consider visible. In points.
    static let extraMargin: CGFloat = 2
    
    /// Defines how large is the vertical span of text being looked at, depending on the zoom level
    static let vSpanDenom: CGFloat = 3
    
    /// Defines tolerance proportion for line sizes when creating selections (lines **bigger** than this fraction - when compared to other lines - will be discarded)
    static let lineAutoSelectionTolerance: CGFloat = 0.1
    
    /// Name of thumbnail button down (pressed) image
    static let thumbButton_DOWN = "TB_ThumbD"
    
    /// Name of thumbnail button up (not pressed) image
    static let thumbButton_UP = "TB_ThumbU"
    
    /// Minimum size of thumbnail side view to be considered as "visible"
    static let minThumbSideViewWidth: CGFloat = 20
    
    /// Default size of thumbnail side view (set when pressing button)
    static let defaultThumbSideViewWidth: CGFloat = 200
    
    // MARK: - Notifications
    
    /// String identifying the notification sent when auto anootation is complete
    static let autoAnnotationComplete = "hiit.PeyeDF.autoAnnotationComplete"
    
    /// String identifying the notification sent when a new document is opened / switched to
    static let occlusionChangeNotification = "hiit.PeyeDF.occlusionChangeNotification"
    
    /// String identifying the notification sent when a new document is opened / switched to
    static let documentChangeNotification = "hiit.PeyeDF.documentChangeNotification"
    
    private static func makeDateFormatter() -> NSDateFormatter {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = PeyeConstants.diMeDateFormat
        return dateFormatter
    }
}

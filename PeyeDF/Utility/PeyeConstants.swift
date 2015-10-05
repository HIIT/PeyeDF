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
    
    // MARK: - Preferences
    // Remember to set some default values in the appdelegate for each preference
    
    /// Dominant eye
    static let prefDominantEye = "eye.dominant"
    
    /// Use midas
    static let prefUseMidas = "midas.use"
    
    /// Monitor DPI
    static let prefMonitorDPI = "monitor.DPI"
    
    /// Annotation line thickness
    static let prefAnnotationLineThickness = "annotations.lineThickness"
    
    /// URL of the DiMe server (bound in the preferences window)
    static let prefServerURL = "serverinfo.url"
    
    /// Username of the DiMe server (bound in the preferences window)
    static let prefServerUserName = "serverinfo.userName"
    
    /// Password of the DiMe server (bound in the preferences window)
    static let prefServerPassword = "serverinfo.password"
    
    /// Wheter we want to push an event at every window focus event (bound in the preferences window)
    static let prefSendEventOnFocusSwitch = "preferences.sendEventOnFocusSwitch"
    
    /// MARK: - History-specific constants
    
    /// Amount of seconds that are needed before we assume user is reading (after, we start recording the current readingevent).
    static let minReadTime: NSTimeInterval = 2.5
    
    /// Amount of seconds after which we always close a reading event.
    /// (It is assumed the user went away from keyboard).
    static let maxReadTime: NSTimeInterval = 600
    
    /// Date formatter shared in DiMe submissions (uses date format below)
    static let diMeDateFormatter = PeyeConstants.makeDateFormatter()
    
    /// Date format used for DiMe submission
    static let diMeDateFormat = "Y'-'MM'-'d'T'HH':'mm':'ssZ"
    
    // MARK: - Midas
    
    /// Name of the midas node containing raw (gaze) data
    static let midasRawNodeName = "raw_eyestream"
    
    /// Name of the midas node containing event data
    static let midasEventNodeName = "event_eyestream"
    
    /// List of all channel names in raw stream, in order
    static let midasRawChannelNames = ["timestamp", "leftGazeX", "leftGazeY", "leftDiam", "leftEyePositionX", "leftEyePositionY", "leftEyePositionZ", "rightGazeX", "rightGazeY", "rightDiam", "rightEyePositionX", "rightEyePositionY", "rightEyePositionZ"]
    
    /// List of all channel names in event stream, in order
    static let midasEventChannelNames = ["eye", "startTime", "endTime", "duration", "positionX", "positionY"]
    
    // MARK: - Debug
    
    /// Column name for debug table. Make sure this identifier matches the table view id in the storyboard
    static let debugTitleColName = "DebugTitleColumn"
    
    /// Column name for debug table. Make sure this identifier matches the table view id in the storyboard
    static let debugDescColName = "DebugDescriptionColumn"
    
    /// Column name for debug table. Make sure this identifier matches the table view id in the storyboard
    static let debugTimeColName = "DebugTimeColumn"
    
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
    
    /// What is returned when a coordinate on screen is outside the current pdfView.
    static let outOfViewTriplet = (x: CGFloat(-1.0), y: CGFloat(-1.0), pageIndex: -1)
    
    /// What is returned when a coordinate on screen is outside the current page.
    static let outOfPageTriplet = (x: CGFloat(-2.0), y: CGFloat(-2.0), pageIndex: -2)
    
    /// Default window width. Make sure this is above min document window width in storyboard.
    static let docWindowWidth: CGFloat = 1100
    
    /// Default window height. Make sure this is above min document window height in storyboard.
    static let docWindowHeight: CGFloat = 700
    
    /// When comparing rectangles, they are at the same horizontal positions if they are separated by less than this amount of points.
    static let rectHorizontalTolerance: CGFloat = 2.0
    
    /// How much space do we leave between margins of the window and text we consider visible. In points.
    static let extraMargin: CGFloat = 2
    
    /// Defines how large is the vertical span of text being looked at, depending on the zoom level
    static let vSpanDenom: CGFloat = 3
    
    /// Defines tolerance proportion for line sizes when creating selections (lines **bigger** than this fraction - when compared to other lines - will be discarded)
    static let lineAutoSelectionTolerance: CGFloat = 0.1
    
    /// Name of search button down (pressed) image
    static let searchButton_DOWN = "TB_SearchD"
    
    /// Name of search button up (not pressed) image
    static let searchButton_UP = "TB_SearchU"
    
    /// Name of annotation button down (pressed) image
    static let annotateButton_DOWN = "TB_AnnotateD"
    
    /// Name of annotation button up (not pressed) image
    static let annotateButton_UP = "TB_AnnotateU"
    
    /// Name of thumbnail button down (pressed) image
    static let thumbButton_DOWN = "TB_ThumbD"
    
    /// Name of thumbnail button up (not pressed) image
    static let thumbButton_UP = "TB_ThumbU"
    
    /// Minimum size of search panel view to be considered as "visible"
    static let minSearchPanelViewHeight: CGFloat = 20
    
    /// Default size of search panel view (set when pressing button)
    static let defaultSearchPanelViewHeight: CGFloat = 180
    
    /// Minimum size of thumbnail side view to be considered as "visible"
    static let minThumbSideViewWidth: CGFloat = 20
    
    /// Default size of thumbnail side view (set when pressing button)
    static let defaultThumbSideViewWidth: CGFloat = 200
    
    // MARK: - Notifications
    
    /// String notifying that something changed in the dime connection.
    ///
    /// **UserInfo dictionary fields**:
    ///
    /// - "available": Boolean, true if dime went up, false if down
    static let diMeConnectionNotification = "hiit.PeyeDF.diMeConnectionChange"
    
    /// String notifying that Midas' connection status changed
    ///
    /// **UserInfo dictionary fields**:
    ///
    /// - "available": Boolean, true if midas went up, false if down
    static let midasConnectionNotification = "hiit.PeyeDF.midasConnectionChanged"
    
    /// String identifying the notification sent when a new sample is received from midas
    static let newMidasSampleNotification = "hiit.PeyeDF.midasNewSample"
    
    /// String identifying the notification sent when auto annotation is complete
    static let autoAnnotationComplete = "hiit.PeyeDF.autoAnnotationComplete"
    
    /// String identifying the notification sent when a new document is opened / switched to
    static let occlusionChangeNotification = "hiit.PeyeDF.occlusionChangeNotification"
    
    /// String identifying the notification sent when a new document is opened / switched to
    static let documentChangeNotification = "hiit.PeyeDF.documentChangeNotification"
    
    // MARK: - Static functions
    
    private static func makeDateFormatter() -> NSDateFormatter {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = PeyeConstants.diMeDateFormat
        return dateFormatter
    }
}

// MARK: - Rectangle reading classes

/// How important is a paragraph
public enum ReadingClass: Int {
    case Unset = 0
    case Viewport = 10
    case Paragraph_floating = 13
    case Paragraph_united = 14
    case Read = 20
    case Interesting = 30
    case Critical = 40
}

/// What decided that a paragraph is important
public enum ClassSource: Int {
    case Unset = 0
    case Viewport = 1
    case Click = 2
    case Eye = 3
}

/// Midas raw channel numbers
public enum midasRawChanNumbers: Int {
    case timestamp = 0, leftGazeX, leftGazeY, leftDiam, leftEyePositionX, leftEyePositionY, leftEyePositionZ, rightGazeX, rightGazeY, rightDiam, rightEyePositionX, rightEyePositionY, rightEyePositionZ
}

/// Midas event channel numbers
public enum midasEventChanNumber: Int {
    case eye = 0, startTime, endTime, duration, positionX, positionY
}

/// Eye (left or right). Using same coding as SMI_LSL data streaming.
public enum Eye: Int {
    case left = -1
    case right = 1
}
//
// Copyright (c) 2015 Aalto University
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
import Cocoa

/// All constants used are put here for convenience.
struct PeyeConstants {
    
    // MARK: - Preferences
    // Remember to set some default values in the appdelegate for each preference
    
    /// Whether we want to try to fetch metadata on document open
    static let prefDownloadMetadata = "metadata.usecrossref"
    
    /// Whether we want "annotate" to be enabled by default
    static let prefEnableAnnotate = "annotate.defaultOn"
    
    /// Dominant eye
    static let prefDominantEye = "eye.dominant"
    
    /// Use midas on start
    static let prefUseMidas = "midas.use"
    
    /// Draw gazed-upon paragraphs in refinder
    static let prefRefinderDrawGazedUpon = "refinder.drawGazedUpon"
    
    /// Draw debug circle
    static let prefDrawDebugCircle = "debug.drawCircle"
    
    /// Monitor DPI
    static let prefMonitorDPI = "monitor.DPI"
    
    /// Annotation line thickness
    static let prefAnnotationLineThickness = "annotations.lineThickness"
    
    /// URL of the DiMe server (bound in the preferences window)
    static let prefDiMeServerURL = "dime.serverinfo.url"
    
    /// Username of the DiMe server (bound in the preferences window)
    static let prefDiMeServerUserName = "dime.serverinfo.userName"
    
    /// Password of the DiMe server (bound in the preferences window)
    static let prefDiMeServerPassword = "dime.serverinfo.password"
    
    /// Wheter we want to push an event at every window focus event (bound in the preferences window)
    static let prefSendEventOnFocusSwitch = "preferences.sendEventOnFocusSwitch"
    
    /// MARK: - History-specific constants
    
    /// Amount of seconds that are needed before we assume user is reading (after, we start recording the current readingevent).
    static let minReadTime: NSTimeInterval = 2.0
    
    /// Amount of seconds after which we always close a reading event.
    /// (It is assumed the user went away from keyboard).
    static let maxReadTime: NSTimeInterval = 600
    
    /// Date formatter shared in DiMe submissions (uses date format below)
    static let diMeDateFormatter = PeyeConstants.makeDateFormatter()
    
    /// Date format used for DiMe submission
    static let diMeDateFormat = "Y'-'MM'-'d'T'HH':'mm':'ssZ"
    
    /// Page area is multiplied by this constant, to reduce total area size (to remove margins, etc)
    static let pageAreaMultiplier = 0.125
    
    // MARK: - Midas
    
    /// Name of the midas node containing raw (gaze) data
    static let midasRawNodeName = "raw_eyestream"
    
    /// Name of the midas node containing event data
    static let midasEventNodeName = "event_eyestream"
    
    /// List of all channel names in raw stream, in order
    static let midasRawChannelNames = ["timestamp", "leftGazeX", "leftGazeY", "leftDiam", "leftEyePositionX", "leftEyePositionY", "leftEyePositionZ", "rightGazeX", "rightGazeY", "rightDiam", "rightEyePositionX", "rightEyePositionY", "rightEyePositionZ"]
    
    /// List of all channel names in event stream, in order
    static let midasEventChannelNames = ["eye", "startTime", "endTime", "duration", "positionX", "positionY", "marcotime"]
    
    /// Eye fixation data which has a unix time within this range of its own exclude
    /// unixtimes won't be sent to dime (used to reject data gathered close to paragraph
    /// marking events
    static let excludeEyeUnixTimeMs = 1000
    
    // MARK: - Eye Analysis
    
    /// Minimum number of fixations for data to be exported
    static let minNOfFixations = 3
    
    // MARK: - Debug
    
    /// Column name for debug table. Make sure this identifier matches the table view id in the storyboard
    static let debugTitleColName = "DebugTitleColumn"
    
    /// Column name for debug table. Make sure this identifier matches the table view id in the storyboard
    static let debugDescColName = "DebugDescriptionColumn"
    
    /// Column name for debug table. Make sure this identifier matches the table view id in the storyboard
    static let debugTimeColName = "DebugTimeColumn"
    
    // MARK: - Annotations
    
    /// Documents which have been seen / read / marked as interesting less than this amount won't be sent
    /// as summary events to DiMe
    static let minProportion = 0.001
    
    /// Space between the "selection" (seen paragraph) rectangle and its line (in page points)
    static let annotationLineDistance: CGFloat = 7
    
    /// Default color of the read annotation lines
    static let annotationColourRead: NSColor = NSColor(red: 0.24, green: 0.74, blue: 0.97, alpha: 0.75)
    
    /// Default color of the "interesting" annotation lines
    static let annotationColourInteresting: NSColor = NSColor(red: 0.92, green: 0.71, blue: 0.43, alpha: 0.75)
    
    /// Default color of the "critical" annotation lines
    static let annotationColourCritical: NSColor = NSColor(red: 0.99, green: 0.24, blue: 0.26, alpha: 0.75)
    
    /// Default color for "floating" paragraphs detected using fixations
    static let markColourParagraph: NSColor = NSColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 0.75)
    
    /// Default color for paragraphs when showing raw attention value (assuming attVal between 0 and 1)
    static func markColourAttnVal(attnVal: NSNumber) -> NSColor {
        return NSColor(red: 0.675, green: 0.25, blue: 0.675, alpha: attnVal as CGFloat)
    }
    
    /// Default color for searched, found and looked at string queries
    static let markColourFoundStrings: NSColor = NSColor(red: 0.88, green: 0.89, blue: 0.0, alpha: 0.85)
    
    /// Array of all annotation colours, in ascending order of importance
    static let annotationAllColours = [PeyeConstants.annotationColourRead,
                                       PeyeConstants.annotationColourInteresting,
                                       PeyeConstants.annotationColourCritical]
    
    /// Dictionary of annotation colours for their given "importance"
    static let annotationColours: [ReadingClass: NSColor] = [.Read: annotationColourRead,
                                                             .Interesting: annotationColourInteresting,
                                                             .Critical: annotationColourCritical]
    
    /// Dictionary of annotation colours for smi
    static let smiColours: [ReadingClass: NSColor] = [.Paragraph: markColourParagraph]
    
    // MARK: - Other globals
    
    /// Open windows regularly submit a summary event every time this amount of time passes
    static let regularSummaryEventInterval: NSTimeInterval = 1 * 60
    
    /// Default window width. Make sure this is above min document window width in storyboard.
    static let docWindowWidth: CGFloat = 1100
    
    /// Default window height. Make sure this is above min document window height in storyboard.
    static let docWindowHeight: CGFloat = 700
    
    /// When comparing rectangles, they are at the same horizontal positions if they are separated by less than this amount of points.
    static let rectHorizontalTolerance: CGFloat = 5.0
    
    /// When comparing rectangles, they are at the same vertical positions if they are separated by less than this amount of points.
    static let rectVerticalTolerance: CGFloat = 5.0
    
    /// Minimum rectangle height (based on 0.25 inch at 72 dpi)
    static let minRectHeight: CGFloat = 0.25 * 72
    
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
    static let defaultThumbSideViewWidth: CGFloat = 150
    
    /// Sometimes page numbers are returned out of range from PdfView instances.
    /// To correct this issue, this constant specifies an (arbitrary) maximum acceptable page index.
    static let maxAcceptablePageIndex: Int = 50000
    
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
    
    /// String notifying that eyes were lost/seen
    ///
    /// **UserInfo dictionary fields**:
    ///
    /// - "available": Boolean, true if eyes can be seen, false if they were lost
    static let eyesAvailabilityNotification = "hiit.PeyeDF.eyesAvailabilityNotification"
    
    /// String identifying the notification sent when a new raw sample (for eye position) is received from midas.
    /// The sample regarding the last (most recent) event is sent
    ///
    /// **UserInfo dictionary fields**:
    /// - "xpos": last seen position, x
    /// - "ypos": last seen position, y (in SMI coordinate system, which is different from OS X)
    /// - "zpos": last seen position, z (distance from camera)
    static let midasEyePositionNotification = "hiit.PeyeDF.midasEyePosition"
    
    /// String idenfitying the notification sent when a user manually marks a paragraph
    ///
    /// **UserInfo dictionary fields**:
    /// - "unixtime": the unixtime associated to the marking event
    static let manualParagraphMarkNotification = "hiit.PeyeDF.manualMarkEvent"
    
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

/// Midas raw channel numbers
public enum midasRawChanNumbers: Int {
    case timestamp = 0, leftGazeX, leftGazeY, leftDiam, leftEyePositionX, leftEyePositionY, leftEyePositionZ, rightGazeX, rightGazeY, rightDiam, rightEyePositionX, rightEyePositionY, rightEyePositionZ
}

/// Midas event channel numbers
public enum midasEventChanNumber: Int {
    case eye = 0, startTime, endTime, duration, positionX, positionY, marcotime
}

/// Eye (left or right). Using same coding as SMI_LSL data streaming.
public enum Eye: Int {
    case left = -1
    case right = 1
}
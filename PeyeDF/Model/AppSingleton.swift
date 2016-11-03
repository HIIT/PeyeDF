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
import Quartz
import XCGLogger
//
//fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
//  switch (lhs, rhs) {
//  case let (l?, r?):
//    return l < r
//  case (nil, _?):
//    return true
//  default:
//    return false
//  }
//}
//
//fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
//  switch (lhs, rhs) {
//  case let (l?, r?):
//    return l > r
//  default:
//    return rhs < lhs
//  }
//}
//

/// Used to share common instances across the whole application, including posting history notifications to the store, access to logs, storyboards, eye tracking data.
class AppSingleton {
    
    static let mainStoryboard = NSStoryboard(name: "Main", bundle: nil)
    static let refinderStoryboard = NSStoryboard(name: "Refinder", bundle: nil)
    static let tagsStoryboard = NSStoryboard(name: "Tags", bundle: nil)
    static let collaborationStoryboard = NSStoryboard(name: "Collaboration", bundle: nil)
    static let appDelegate = NSApplication.shared().delegate! as! AppDelegate
    static let findPasteboard = NSPasteboard(name: NSFindPboard)
        
    static let log = AppSingleton.createLog()
    static fileprivate(set) var logsURL: URL?
    
    /// The class that provides eye tracking data (set by app delegate on start)
    static var eyeTracker: EyeDataProvider? = nil
    
    /// Convenience getter for user's distance from screen, which defaults to 80cm
    /// if not known
    static var userDistance: CGFloat { get {
        if let tracker = eyeTracker {
            return tracker.lastValidDistance
        } else {
            return 800
        }
    } }
    
    /// The user's dominant eye, as set in the preferences window.
    static var dominantEye: Eye { get {
        let eyeRaw = UserDefaults.standard.object(forKey: PeyeConstants.prefDominantEye) as! Int
        return Eye(rawValue: eyeRaw)!
    } set {
        UserDefaults.standard.set(newValue.rawValue, forKey: PeyeConstants.prefDominantEye)
    } }
    
    /// The dimensions of the screen the application is running within.
    /// It is assumed there is only one screen when using eye tracking.
    static var screenRect = NSRect()
    
    /// Position of new PDF Document window (for cascading)
    static var nextDocWindowPos = NSPoint(x: 200, y: 350)
    
    /// Convenience function to get monitor DPI
    static func getMonitorDPI() -> Int {
        return UserDefaults.standard.object(forKey: PeyeConstants.prefMonitorDPI) as! Int
    }
    
    /// Gets DPI programmatically
    static func getComputedDPI() -> Int? {
        if NSScreen.screens()?.count ?? 0 > 1 {
            AppSingleton.alertUser("Can't get dpi", infoText: "Using multiple monitors is not supported yet.")
            return nil
        } else {
            let screen = NSScreen.main()
            let id = CGMainDisplayID()
            let mmSize = CGDisplayScreenSize(id)

            let pixelWidth = screen!.frame.width  //we could do * screen!.backingScaleFactor but OS X normalizes DPI
            let inchWidth = cmToInch(mmSize.width / 10)
            return Int(round(pixelWidth / inchWidth))
        }
    }
        
    /// Convenience function to set recently used tags
    static func updateRecentTags(_ newTag: String) {
        /// Recent tags is a list of strings in which the first string is the most recent
        var recentTags: [String] = UserDefaults.standard.object(forKey: TagConstants.defaultsSavedTags) as! [String]
        if !recentTags.contains(newTag) {
            recentTags.insert(newTag, at: 0)
            if recentTags.count > TagConstants.nOfSavedTags {
                recentTags.removeSubrange(TagConstants.nOfSavedTags..<recentTags.count)
            }
            UserDefaults.standard.set(recentTags, forKey: TagConstants.defaultsSavedTags)
        }
    }
    
    /// Convenience function to show an alerting alert (with additional info)
    ///
    /// - parameter message: The message to show
    /// - parameter infoText: shows additional text
    static func alertUser(_ message: String, infoText: String) {
        let myAl = NSAlert()
        myAl.alertStyle = .warning
        myAl.icon = NSImage(named: "NSCaution")
        myAl.messageText = message
        myAl.informativeText = infoText
        DispatchQueue.main.async {
            myAl.runModal()
        }
    }
    
    /// Convenience function to show an alerting alert (without additional info)
    ///
    /// - parameter message: The message to show
    static func alertUser(_ message: String) {
        let myAl = NSAlert()
        myAl.alertStyle = .warning
        myAl.icon = NSImage(named: "NSCaution")
        myAl.messageText = message
        DispatchQueue.main.async {
            myAl.runModal()
        }
    }
    
    /// Set up console and file log
    fileprivate static func createLog() -> XCGLogger {
        let dateFormat = "Y'-'MM'-'d'T'HH':'mm':'ssZ"  // date format for string appended to log
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormat
        let appString = dateFormatter.string(from: Date())
        
        var firstLine: String = "Log directory succesfully created / present"
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(Bundle.main.bundleIdentifier!)
        do {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            firstLine = "Error creating log directory: \(error)"
        }
        AppSingleton.logsURL = tempURL
        let logFilePathURL = tempURL.appendingPathComponent("XCGLog_\(appString).log")
        let newLog = XCGLogger.default
        newLog.setup(level: .debug, showThreadName: true, showLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: logFilePathURL, fileLevel: .debug)
        newLog.debug(firstLine)
        
        return newLog
    }
    
}

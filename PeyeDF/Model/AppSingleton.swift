//
//  AppSingleton.swift
//  PeyeDF
//
//  Created by Marco Filetti on 23/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa
import Quartz

/// Used to share states across the whole application, including posting history notifications to store. Contains:
///
/// - storyboard: the "Main" storyboard
/// - log: XCGLogger instance to log information to console and file
class AppSingleton {
    
    static let mainStoryboard = NSStoryboard(name: "Main", bundle: nil)
    static let refinderStoryboard = NSStoryboard(name: "Refinder", bundle: nil)
    static let appDelegate = NSApplication.sharedApplication().delegate! as! AppDelegate
    
    static let log = AppSingleton.createLog()
    static private(set) var logsURL = NSURL()
    
    /// The dimensions of the screen the application is running within.
    /// It is assumed there is only one screen when using eye tracking.
    static var screenRect = NSRect()
    
    /// Convenience function to get monitor DPI
    static func getMonitorDPI() -> CGFloat {
        let dpi: Int = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefMonitorDPI) as! Int
        return CGFloat(dpi)
    }
    
    /// Convenience function to get preferred eye
    static func getDominantEye() -> Eye {
        let eyeRaw = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDominantEye) as! Int
        return Eye(rawValue: eyeRaw)!
    }
    
    /// Convenience function to show an alerting alert
    ///
    /// - parameter message: The message to show
    /// - parameter infoText: If not nil (default), shows additional text
    static func alertUser(message: String, infoText: String? = nil) {
        let myAl = NSAlert()
        myAl.alertStyle = .WarningAlertStyle
        myAl.icon = NSImage(named: "NSCaution")
        myAl.messageText = message
        if let infoText = infoText {
            myAl.informativeText = infoText
        }
        myAl.runModal()
    }
    
    /// Set up console and file log
    private static func createLog() -> XCGLogger {
        let dateFormat = "Y'-'MM'-'d'T'HH':'mm':'ssZ"  // date format for string appended to log
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = dateFormat
        let appString = dateFormatter.stringFromDate(NSDate())
        
        var firstLine: String = "Log directory succesfully created / present"
        let tempURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent(NSBundle.mainBundle().bundleIdentifier!)
        do {
            try NSFileManager.defaultManager().createDirectoryAtURL(tempURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            firstLine = "Error creating log directory: \(error)"
        }
        AppSingleton.logsURL = tempURL
        let logFilePathURL = tempURL.URLByAppendingPathComponent("XCGLog_\(appString).log")
        let newLog = XCGLogger.defaultInstance()
        newLog.setup(.Debug, showThreadName: true, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: logFilePathURL, fileLogLevel: .Debug)
        newLog.debug(firstLine)
        
        return newLog
    }
    
}

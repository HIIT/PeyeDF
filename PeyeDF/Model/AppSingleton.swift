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
    static let storyboard = NSStoryboard(name: "Main", bundle: nil)
    
    static let log = AppSingleton.createLog()
    
    /// Convenience function to get monitor DPI
    static func getMonitorDPI() -> CGFloat {
        let dpi: Int = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefMonitorDPI) as! Int
        return CGFloat(dpi)
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
        var error: NSError? = nil
        var firstLine: String = "Log directory succesfully created / present"
        let tempURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent(NSBundle.mainBundle().bundleIdentifier!)
        let tempDirBase = tempURL.URLString
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(tempDirBase, withIntermediateDirectories: true, attributes: nil)
        } catch let error1 as NSError {
            error = error1
            firstLine = "Error creating log directory: " + error!.description
        }
        let logFilePathURL = tempURL.URLByAppendingPathComponent("XCGLog.log")
        let newLog = XCGLogger.defaultInstance()
        newLog.setup(.Debug, showThreadName: true, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: logFilePathURL.URLString, fileLogLevel: .Debug)
        newLog.debug(firstLine)
        return newLog
    }
    
}

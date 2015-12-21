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
    
    /// Returns HTTP headers used for DiMe connection
    static var dimeHeaders: [String: String] = {
        let user: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerUserName) as! String
        let password: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerPassword) as! String
        
        let credentialData = "\(user):\(password)".dataUsingEncoding(NSUTF8StringEncoding)!
        let base64Credentials = credentialData.base64EncodedStringWithOptions([])
        
        return ["Authorization": "Basic \(base64Credentials)"]
    }()
    
    /// Returns dime server url
    static var dimeUrl: String = {
        return NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerURL) as! String
    }()
    
    /// Convenience function to get monitor DPI
    static func getMonitorDPI() -> Int {
        return NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefMonitorDPI) as! Int
    }
    
    /// Gets DPI programmatically
    static func getComputedDPI() -> Int? {
        if NSScreen.screens()?.count > 1 {
            AppSingleton.alertUser("Can't get dpi", infoText: "Using multiple monitors is not supported yet.")
            return nil
        } else {
            let screen = NSScreen.mainScreen()
            let id = CGMainDisplayID()
            let mmSize = CGDisplayScreenSize(id)

            let pixelWidth = screen!.frame.width  //we could do * screen!.backingScaleFactor but OS X normalizes DPI
            let inchWidth = cmToInch(mmSize.width / 10)
            return Int(round(pixelWidth / inchWidth))
        }
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

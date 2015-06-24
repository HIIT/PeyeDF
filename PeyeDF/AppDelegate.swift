//
//  AppDelegate.swift
//  PeyeDF
//
//  Created by Marco Filetti on 10/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Cocoa
import Quartz.PDFKit.PDFView

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)!
        let debugWindowController = storyboard.instantiateControllerWithIdentifier("DebugWindow") as? NSWindowController
        debugWindowController?.showWindow(nil)
        
        AppSingleton.debugWinInfo.windowController = debugWindowController
        AppSingleton.debugWinInfo.debugController = debugWindowController?.contentViewController as? DebugController
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldOpenUntitledFile(sender: NSApplication) -> Bool {
        return false
    }

}


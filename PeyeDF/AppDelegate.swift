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
        // Instantiate and create debug window
        let debugWindowController = AppSingleton.storyboard.instantiateControllerWithIdentifier("DebugWindow") as? NSWindowController
        debugWindowController?.showWindow(nil)
        
        // Initialize singleton with debug pointers
        AppSingleton.debugWinInfo.windowController = debugWindowController
        AppSingleton.debugWinInfo.debugController = debugWindowController?.contentViewController as? DebugController
    }

    @IBAction func thisDocMdata(sender: AnyObject) {
        if let mainWin = NSApplication.sharedApplication().mainWindow {
            let peyeDoc: PeyeDocument = NSDocumentController.sharedDocumentController().documentForWindow(mainWin) as! PeyeDocument
            let myAl = NSAlert()
            
            
            var allTextHead = "No text found"
            if let aText = peyeDoc.trimmedText {  // we assume no text if less than one character is present
                let ei = advance(aText.startIndex, 500)
                allTextHead = aText.substringToIndex(ei)
            }
            myAl.messageText = "Filename: \(peyeDoc.filename)\nTitle: \(peyeDoc.title)\nAuthor(s):\(peyeDoc.authors)\nAll Text (first 500 chars): \(allTextHead)"
            myAl.beginSheetModalForWindow(mainWin, completionHandler: nil)
        }
    }
    
    @IBAction func allDocMetadata(sender: AnyObject) {
        let doci = NSDocumentController.sharedDocumentController().documents
        var outString = ""
        var inum = 1
        for doc: PeyeDocument in doci as! [PeyeDocument] {
            outString += "-- Document \(inum) --\n" +
            "Filename: \(doc.filename)\n" +
            "Title: \(doc.title)\nAuthor(s):\(doc.authors)\n\n"
            ++inum
        }
        if let mainWin = NSApplication.sharedApplication().mainWindow {
            let myAl = NSAlert()
            myAl.messageText = outString
            myAl.beginSheetModalForWindow(mainWin, completionHandler: nil)
        }
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldOpenUntitledFile(sender: NSApplication) -> Bool {
        return false
    }

}


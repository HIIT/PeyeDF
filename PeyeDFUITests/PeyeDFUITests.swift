//
//  PeyeDFUITests.swift
//  PeyeDFUITests
//
//  Created by Marco Filetti on 03/05/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import XCTest

class PeyeDFUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    /// Simply clicks on the "Tag" button after opening a test file and removes the second tag
    func testTags_VerySimple() {
        
        openTestFile()
        
        let app = XCUIApplication()
        let calvodmelloPdfWindow = app.windows["CalvoDMello.pdf"]
        
        let toolbarsQuery = calvodmelloPdfWindow.toolbars
        toolbarsQuery.buttons["Tag"].click()
        
        let calvoEtAl2009PdfWindow = XCUIApplication().windows["CalvoDMello.pdf"]
        calvoEtAl2009PdfWindow.groups["PDF Content"].click()
        
        let clickVector = CGVector(dx: 0.2, dy: 0.5)
        calvoEtAl2009PdfWindow.groups["PDF Content"].staticTexts["PDF Static Text"].coordinate(withNormalizedOffset: clickVector).doubleClick()
        
        toolbarsQuery.buttons["Tag"].click()
        
        putInPasteboard("test")
        let windowPopovers = calvodmelloPdfWindow.popovers
        let textField = windowPopovers.children(matching: .textField).element
        textField.typeKey("v", modifierFlags:.command)  // gets stuck here because of auto completion
        windowPopovers.staticTexts["tagging text"].click()
        windowPopovers.children(matching: .checkBox).matching(identifier: "Add Tag Button").element.click()
    }
    
    /// Opens a pdf file found in the test bundle (Calvo and Dmello)
    func openTestFile() {
        // Open a test file (CalvoDMello.pdf)
        let testPDFURL = Bundle(for: type(of: self)).url(forResource: "CalvoDMello", withExtension: "pdf")
        
        // put path of file in pasteboard
        let textToEnter = testPDFURL!.relativePath
        putInPasteboard(textToEnter)
        
        let app = XCUIApplication()
        app.typeKey("o", modifierFlags:.command)
        
        let xsidebarheaderCell = app.outlines["sidebar"].children(matching: .outlineRow).element(boundBy: 0).cells.containing(.staticText, identifier:"xSidebarHeader").element
        xsidebarheaderCell.typeKey("g", modifierFlags:[.command, .shift])
        let sheetsQuery = app.sheets
        let textField = sheetsQuery.children(matching: .textField).element
        textField.click()
        
        xsidebarheaderCell.typeKey("a", modifierFlags:.command)
        xsidebarheaderCell.typeKey("v", modifierFlags:.command)
        
        app.sheets.buttons["Go"].click()
        app.buttons["Open"].click()
        
    }
    
    /// Places an arbitrary string in the global pasteboard
    func putInPasteboard(_ string: String) {
        NSPasteboard.general().declareTypes([NSStringPboardType], owner: self)
        NSPasteboard.general().setString(string, forType: NSStringPboardType)
    }
    
}

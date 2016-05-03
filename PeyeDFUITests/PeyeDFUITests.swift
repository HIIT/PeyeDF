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
        let popoversQuery = toolbarsQuery.popovers
        toolbarsQuery.buttons["Tag"].click()
        popoversQuery.childrenMatchingType(.CheckBox).matchingIdentifier("Remove Tag Button").elementBoundByIndex(1).click()
//        let textField = popoversQuery.childrenMatchingType(.TextField).element
//        textField.typeText("test\r")
//        textField.typeText("test2\r")
//        
        
    }
    
    /// Opens a pdf file found in the test bundle (Calvo and Dmello)
    func openTestFile() {
        // Open a test file (CalvoDMello.pdf)
        let testPDFURL = NSBundle(forClass: self.dynamicType).URLForResource("CalvoDMello", withExtension: "pdf")
        
        // put path of file in pasteboard
        let textToEnter = testPDFURL!.relativePath!
        putInPasteboard(textToEnter)
        
        let app = XCUIApplication()
        app.typeKey("o", modifierFlags:.Command)
        
        let xsidebarheaderCell = app.outlines["sidebar"].childrenMatchingType(.OutlineRow).elementBoundByIndex(0).cells.containingType(.StaticText, identifier:"xSidebarHeader").element
        xsidebarheaderCell.typeKey("g", modifierFlags:[.Command, .Shift])
        let sheetsQuery = app.sheets
        let textField = sheetsQuery.childrenMatchingType(.TextField).element
        textField.click()
        
        xsidebarheaderCell.typeKey("a", modifierFlags:.Command)
        xsidebarheaderCell.typeKey("v", modifierFlags:.Command)
        
        app.sheets.buttons["Go"].click()
        app.buttons["Open"].click()
    }
    
    /// Places an arbitrary string in the global pasteboard
    func putInPasteboard(string: String) {
        NSPasteboard.generalPasteboard().declareTypes([NSStringPboardType], owner: self)
        NSPasteboard.generalPasteboard().setString(string, forType: NSStringPboardType)
    }
    
}

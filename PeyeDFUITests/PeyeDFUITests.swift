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
        
        let pdfContent = calvoEtAl2009PdfWindow.scrollViews.firstMatch
        
        pdfContent.click()
        
        let clickVector = CGVector(dx: 0.2, dy: 0.5)
        
        pdfContent.coordinate(withNormalizedOffset: clickVector).doubleClick()
        
        toolbarsQuery.buttons["Tag"].click()
        
        let windowPopovers = calvodmelloPdfWindow.popovers
        let textField = windowPopovers.children(matching: .textField).element
        textField.typeText("Testing tag")
        
        windowPopovers.textFields["Input tag field"].click()
        windowPopovers.children(matching: .checkBox).matching(identifier: "Add Tag Button").element.click()
    }
    
    /// Opens a pdf file found in the test bundle (Calvo and Dmello)
    func openTestFile() {
        // Open a test file (CalvoDMello.pdf)
        let testPDFURL = Bundle(for: type(of: self)).url(forResource: "CalvoDMello", withExtension: "pdf")
        
        // put path of file in pasteboard
        let textToEnter = testPDFURL!.relativePath
        
        let app = XCUIApplication()
        app.typeKey("o", modifierFlags:XCUIElement.KeyModifierFlags.command)
        
        let xsidebarheaderCell = app.outlines["sidebar"].children(matching: .outlineRow).element(boundBy: 0).cells.containing(.staticText, identifier:"xSidebarHeader").element
        xsidebarheaderCell.typeKey("g", modifierFlags:[XCUIElement.KeyModifierFlags.command, XCUIElement.KeyModifierFlags.shift])
        let sheetsQuery = app.sheets
        let textField = sheetsQuery.children(matching: .comboBox).element
        textField.click()
        
        xsidebarheaderCell.typeKey("a", modifierFlags: .command)
        xsidebarheaderCell.typeText(textToEnter)
        
        app.sheets.buttons["Go"].click()
        app.buttons["Open"].firstMatch.click()
        
    }
    
}

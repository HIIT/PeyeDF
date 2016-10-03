//
//  PeyeDF_Questions_UITests.swift
//  PeyeDF Questions UITests
//
//  Created by Marco Filetti on 03/10/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import XCTest

class PeyeDF_Questions_UITests: XCTestCase {
    
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
    
    func testRunRandom() {
        
        // midas is on
        let useMidas = false
        
        // participant json load
        let app = XCUIApplication()
        app.textFields["##"].typeText("5")
        let okButton = app.buttons["OK"]
        okButton.click()
        
        // midas dismiss
        if !useMidas {
            okButton.click()
        }
        
        startAndAnswerAll()
    }
    
    
    func testRunLoaded() {
        
        // midas is on
        let useMidas = false
        
        // participant json load
        let app = XCUIApplication()
        app.textFields["##"].typeText("5")
        
        app.checkBoxes["Pre-load"].click()
        
        let okButton = app.buttons["OK"]
        okButton.click()
        
        // midas dismiss
        if !useMidas {
            okButton.click()
        }
        
        startAndAnswerAll()
    }
    
    /// Convenience function to start and answer all questions
    func startAndAnswerAll() {
        let app = XCUIApplication()
        
        // number of papers
        let nOfPapers = 4
        
        // number of questions
        let nOfQuestions = 4
        
        // number of ttopics
        let nOfTtopics = 3
        
        // number of ttopics (practice)
        let nOfTtopics_P = 2
        
        // number of questions (practice)
        let nOfQuestions_P = 2
        
        // start question mode
        let menuBarsQuery = app.menuBars
        let fileMenuBarItem = menuBarsQuery.menuBarItems["File"]
        fileMenuBarItem.click()
        menuBarsQuery.menuItems["Show refinder"].click()
        fileMenuBarItem.click()
        menuBarsQuery.menuItems["Start questions"].click()
        
        let continueButton = app.buttons["Continue"]
        
        let rndLabs = ["First", "Second", "Third"]
        var rndI: UInt32 = 999
        
        // answer practice
        
        continueButton.click()
        for _ in 0..<nOfTtopics_P {
            for _ in 0..<nOfQuestions_P {
                continueButton.click()
                rndI = arc4random_uniform(UInt32(rndLabs.count))
                let lab = rndLabs[Int(rndI)]
                app.radioButtons[lab + " answer"].click()
                app.buttons["Confirm"].click()
            }
        }
        continueButton.click()
        
        // answer "real" test
        
        for _ in 0..<nOfPapers {
            continueButton.click()
            for _ in 0..<nOfTtopics {
                for _ in 0..<nOfQuestions {
                    continueButton.click()
                    rndI = arc4random_uniform(UInt32(rndLabs.count))
                    let lab = rndLabs[Int(rndI)]
                    app.radioButtons[lab + " answer"].click()
                    app.buttons["Confirm"].click()
                }
            }
            continueButton.click()
        }
        
        // end
        continueButton.click()
        
        // wait 10 seconds
        sleep(10)
        
    }
    
}

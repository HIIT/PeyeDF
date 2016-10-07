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
    
    /// Convenience function to start and answer all questions
    func testQuestionRun() {
        
        // length of break (seconds)
        let breakTime: Double = 5 * 60 + 5 // add small constant for animations, etc
        
        // length of familiarisation time (seconds)
        let familiariseTime: UInt32 = 15 * 60 // add small constant for animations, etc
        
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
        let peyedfQuestionsMenuBarItem = menuBarsQuery.menuBarItems["PeyeDF Questions"]
        peyedfQuestionsMenuBarItem.click()
        menuBarsQuery.menuItems["Preferences…"].click()

        let peyedfPreferencesWindow = app.windows["PeyeDF Preferences"]
        peyedfPreferencesWindow.toolbars.buttons["Experiment"].click()

        let partTestField = peyedfPreferencesWindow.descendants(matching: .textField)["Participant number"]
        partTestField.click()
        partTestField.typeText("2\r")
        
        peyedfPreferencesWindow.descendants(matching: .button)["Start"].click()
        
        let continueButton = app.buttons["Continue"]
        
        let rndLabs = ["First", "Second", "Third"]
        var rndI: UInt32 = 999
        
        // answer practice
        
        continueButton.click() // proceed to paper
        
        sleep(familiariseTime) // familiarise wait

        for _ in 0..<nOfTtopics_P {
            continueButton.click() // see answers
            for _ in 0..<nOfQuestions_P {
                rndI = arc4random_uniform(UInt32(rndLabs.count))
                let lab = rndLabs[Int(rndI)]
                app.radioButtons[lab + " answer"].click()
                app.buttons["Confirm"].click()
            }
        }
        
        continueButton.click() // next paper
        
        // answer "real" test
        
        for pNo in 0..<nOfPapers {
            if pNo == nOfPapers / 2 {
                let predicate = NSPredicate(format: "exists == true")
                expectation(for: predicate, evaluatedWith: continueButton)
                waitForExpectations(timeout: breakTime + 2)
                continueButton.click() 
            }
            continueButton.click()  // see answers
            sleep(familiariseTime) // familiarise wait
            for _ in 0..<nOfTtopics {
                continueButton.click()
                for _ in 0..<nOfQuestions {
                    rndI = arc4random_uniform(UInt32(rndLabs.count))
                    let lab = rndLabs[Int(rndI)]
                    app.radioButtons[lab + " answer"].click()
                    app.buttons["Confirm"].click()
                }
            }
            continueButton.click()  // questions done
        }
        
        // end
        continueButton.click()
        
    }
    
}

//
// Copyright (c) 2018 University of Helsinki, Aalto University
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

class PeyeDF_Questions_UITests: XCTestCase {
    
    // length of break (seconds)
    let breakTime: Double = QuestionConstants.breakTime + 60 // add constant for animations, etc
    
    // length of familiarisation time (seconds)
    let familiariseTime: UInt32 = UInt32(QuestionConstants.familiarizeTime + 60) // add constant for animations, etc
    
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
        
        let startButton = peyedfPreferencesWindow.descendants(matching: .button)["Start"]
        
        XCTAssert(startButton.isEnabled == false, "Start button should be disabled before entering participant number")
        
        let partTestField = peyedfPreferencesWindow.descendants(matching: .textField)["Participant number"]
        partTestField.click()
        partTestField.typeText("2\r")
        
        startButton.click()
        
        let continueButton = app.buttons["Continue"]
        
        // answer practice
        
        continueButton.click() // proceed to familiarise
        waitForExist(element: continueButton, timeout: TimeInterval(familiariseTime))

        for _ in 0..<nOfTtopics_P {
            continueButton.click() // see answers
            for _ in 0..<nOfQuestions_P {
                giveRandomAnswer()
            }
        }
        
        continueButton.click() // proceed to next paper
        
        // answer "real" test
        
        for pNo in 0..<nOfPapers {
            
            // handle break
            if pNo == nOfPapers / 2 {
                waitForExist(element: continueButton, timeout: breakTime)
                continueButton.click()
            }
            
            continueButton.click()  // proceed to familiarise
            waitForExist(element: continueButton, timeout: TimeInterval(familiariseTime))
            
            for _ in 0..<nOfTtopics {
                continueButton.click()  // see answers
                for _ in 0..<nOfQuestions {
                    giveRandomAnswer()
                }
            }
            continueButton.click()  // proceed to next paper
        }
        
        // end
        continueButton.click()
        
    }
    
    /// Answers one out of three possibilites, at random.
    func giveRandomAnswer() {
        let app = XCUIApplication()
        
        XCTAssert(app.buttons["Confirm"].isEnabled == false, "Confirm button should be disabled before receiving answer")
        
        let rndLabs = ["First", "Second", "Third"]
        var rndI: UInt32 = 999
        
        rndI = arc4random_uniform(UInt32(rndLabs.count))
        let lab = rndLabs[Int(rndI)]
        app.radioButtons[lab + " answer"].click()
        app.buttons["Confirm"].click()
    }
    
    /// Wait until an element is shown
    func waitForExist(element: XCUIElement, timeout: TimeInterval) {
        let predicate = NSPredicate(format: "exists == true")
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: timeout)
    }
}

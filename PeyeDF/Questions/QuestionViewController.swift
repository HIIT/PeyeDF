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

import Foundation
import Cocoa
import GameplayKit
import os.log

class QuestionViewController: NSViewController {
    
    // MARK: - Instance variables and init
    
    // Question machine. is static so it can easily be access outside.
    static var questionMachine: GKStateMachine!
    
    /// Alert button shown when eyes are lost (nil if eyes are not lost or unkown)
    var eyeAlertButton: NSButton?
    
    /// Reference to the current document window
    weak var docWindowController: DocumentWindowController?
    
    let appDel = NSApplication.shared().delegate as! AppDelegate
    var givenAnswer: String = ""
    let answerSaver = AnswerSaver(pNo: QuestionSingleton.pNo)
    
    @IBOutlet var topicHead: NSTextField!
    @IBOutlet var questionHead: NSTextField!
    
    @IBOutlet var topicFromTop: NSLayoutConstraint!
    @IBOutlet var topicFromItsLabel: NSLayoutConstraint!
    @IBOutlet var topicLabelFromQuestion: NSLayoutConstraint!
    
    @IBOutlet var topicLabel: NSTextField!
    @IBOutlet var questionLabel: NSTextField!
    
    @IBOutlet var confirmButton: NSButton!
    @IBOutlet var continueButton: NSButton!
    
    @IBOutlet var answerBox: NSBox!
    
    @IBOutlet var answer1: NSButton!
    @IBOutlet var answer2: NSButton!
    @IBOutlet var answer3: NSButton!
    
    @IBAction func continueButtonPress(_ sender: NSButton) {
        (QuestionViewController.questionMachine.currentState as? Advanceable)?.advance()
    }
    
    @IBAction func confirmButtonPress(_ sender: NSButton) {
        self.confirmButton.isEnabled = false
        (QuestionViewController.questionMachine.currentState! as! AnswerQuestion).answer(givenAnswer)
    }
    
    @IBAction func answerButtonPress(_ sender: NSButtonCell) {
        givenAnswer = sender.title
        confirmButton.isEnabled = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(documentChanged(notification:)), name: PeyeConstants.documentChangeNotification, object: nil)
    }
    
    // MARK: - Window arrangement methods
    
    /// Puts the document's window above the question, with a smaller question window below
    /// returns question frame rect
    func moveQuestionBelow() {
        guard let winc = docWindowController, let win = winc.window, let mainS = NSScreen.main() else {
            if #available(OSX 10.12, *) {
                os_log("Failed to capture window or screen references, trying again in one second", type: .error)
            }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1) {
                self.moveQuestionBelow()
            }
            return
        }
        
        var reducedScreenFrame = mainS.visibleFrame
        reducedScreenFrame.size.height -= 300
        reducedScreenFrame.origin.y += 300
        win.setFrame(reducedScreenFrame, display: true, animate: true)
        
        var questionFrame = mainS.visibleFrame
        questionFrame.size.height = 300
        questionFrame.size.width -= 100
        questionFrame.origin.x += 50
        
        let topicDist: CGFloat = 10
        let topicQuestDist: CGFloat = 15

        NSAnimationContext.runAnimationGroup( { context in
            
            self.view.window!.animator().setFrame(questionFrame, display: true)
            
            // Customize the animation parameters.
            context.duration = 1
            context.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            
            self.topicFromTop.animator().constant = topicDist
            self.topicFromItsLabel.animator().constant = topicDist
            self.topicLabelFromQuestion.animator().constant = topicQuestDist
            
            })
        
    }
    
    /// Sets itself up for a new session of questions
    /// - parameter papers: List of papers (and related target topic groups) for this participant
    func begin(withPapers papers: [Paper]) {
        QuestionViewController.questionMachine = GKStateMachine(states: [GivePaper(self, papers: papers),
                                                  FamiliarisePaper(self),
                                                  GiveTopic(self),
                                                  AnswerQuestion(self),
                                                  QuestionsDone(self)])
        QuestionViewController.questionMachine.enter(GivePaper.self)
    }
    
    /// Prepare user to read a new paper (Entered GivePaper. Also initial state.).
    /// Covers the whole screen.
    func prepareMode(showContinue: Bool) {
        guard let mainScreen = NSScreen.main() else {
            return
        }
        
        let screenFrame = mainScreen.visibleFrame
        
        let topicDist: CGFloat = 40
        let topicQuestDist: CGFloat = 80
        self.answerBox.isHidden = true
        self.confirmButton.isEnabled = false
        
        NSAnimationContext.runAnimationGroup( { context in
            
            self.view.window!.animator().setFrame(screenFrame, display: true)
            
            // Customize the animation parameters.
            context.duration = 1
            context.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            
            self.topicFromTop.animator().constant = topicDist
            self.topicFromItsLabel.animator().constant = topicDist
            self.topicLabelFromQuestion.animator().constant = topicQuestDist
            
            }, completionHandler: {
                self.continueButton.isHidden = !showContinue
        })
    }
    
    /// Receive (if argument is true) user's answer.
    /// If argument is false, hide answers.
    func answerMode(_ show: Bool) {
        DispatchQueue.main.async {
            self.confirmButton.isHidden = !show
            self.answerBox.isHidden = !show
            self.confirmButton.isEnabled = !show
            self.continueButton.isHidden = show
        }
    }
    
    // MARK: - Message displaying methods
    
    /// Shows a generic message with title and detail (no topic / question labels)
    func showGenericMessage(_ message: String, title: String) {
        DispatchQueue.main.async {
            self.topicHead.isHidden = true
            self.questionHead.isHidden = true
            self.questionLabel.stringValue = message
            self.topicLabel.stringValue = title
        }
    }
    
    /// Shows a generic message with title and detail (with topic / question labels)
    func showQuestion(_ question: String, topic: String) {
        DispatchQueue.main.async {
            self.topicHead.isHidden = false
            self.questionHead.isHidden = false
            self.questionLabel.stringValue = question
            self.topicLabel.stringValue = topic
        }
    }
    
    /// Shows a label with an answer for each button, after randomising them
    func showAnswers(_ answers: [String]) {
        let shuffled = GKRandomSource.sharedRandom().arrayByShufflingObjects(in: answers)
        DispatchQueue.main.async {
            self.answer1.title = shuffled[0] as! String
            self.answer1.state = NSOffState
            self.answer2.title = shuffled[1] as! String
            self.answer2.state = NSOffState
            self.answer3.title = shuffled[2] as! String
            self.answer3.state = NSOffState
        }
    }
    
    // MARK: - Notification callbacks
    
    @objc func documentChanged(notification: NSNotification) {
        if notification.name == PeyeConstants.documentChangeNotification {
            // associate the window variable to the last document that was opened
            if let doc = notification.object as? NSDocument {
                docWindowController = doc.windowControllers[0] as? DocumentWindowController
            }
        }
    }
    
}

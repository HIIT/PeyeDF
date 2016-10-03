//
//  QuestionWindowController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 11/02/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation
import Cocoa
import GameplayKit

class QuestionViewController: NSViewController {
    
    // Question machine. is static so it can easily be access outside.
    static var questionMachine: GKStateMachine!
    
    /// Alert button shown when eyes are lost (nil if eyes are not lost or unkown)
    var eyeAlertButton: NSButton?
    
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
    
    @IBAction func continueButtonPress(sender: NSButton) {
        (QuestionViewController.questionMachine.currentState as? Advanceable)?.advance()
    }
    
    @IBAction func confirmButtonPress(sender: NSButton) {
        self.confirmButton.isEnabled = false
        (QuestionViewController.questionMachine.currentState! as! AnswerQuestion).answer(givenAnswer)
    }
    
    @IBAction func answerButtonPress(sender: NSButton) {
        givenAnswer = sender.title
        confirmButton.isEnabled = true
    }
    
    /// Sets itself up for a new session of questions
    /// - parameter papers: List of papers (and related target topic groups) for this participant
    func begin(withPapers papers: [Paper]) {
        QuestionViewController.questionMachine = GKStateMachine(states: [GivePaper(self, papers: papers),
                                                  PrepareQuestion(self),
                                                  AnswerQuestion(self),
                                                  QuestionsDone(self)])
        QuestionViewController.questionMachine.enter(GivePaper.self)
    }
    
    /// Prepare user to receive question (AnswerQuestion -> PrepareQuestion. Also initial state.)
    func prepareMode(refinderFrame: NSRect) {
        let topicDist: CGFloat = 40
        let topicQuestDist: CGFloat = 80
        self.confirmButton.isHidden = true
        self.answerBox.isHidden = true
        self.confirmButton.isEnabled = false
        
        NSAnimationContext.runAnimationGroup( { context in
            
            self.view.window!.animator().setFrame(refinderFrame, display: true)
            
            // Customize the animation parameters.
            context.duration = 1
            context.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            
            self.topicFromTop.animator().constant = topicDist
            self.topicFromItsLabel.animator().constant = topicDist
            self.topicLabelFromQuestion.animator().constant = topicQuestDist
            
            }, completionHandler: {
                self.continueButton.isHidden = false
        })
    }
    
    /// Receive user's answer (PrepareQuestion -> AnswerQuestion)
    func answerMode(ownFrame: NSRect) {
        let topicDist: CGFloat = 10
        let topicQuestDist: CGFloat = 15
        self.continueButton.isHidden = true
        self.confirmButton.isEnabled = false
        
        NSAnimationContext.runAnimationGroup( { context in
            
            self.view.window!.animator().setFrame(ownFrame, display: true)
            
            // Customize the animation parameters.
            context.duration = 1
            context.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            
            self.topicFromTop.animator().constant = topicDist
            self.topicFromItsLabel.animator().constant = topicDist
            self.topicLabelFromQuestion.animator().constant = topicQuestDist
            
        }, completionHandler: {
            self.confirmButton.isHidden = false
            self.answerBox.isHidden = false
        })
    }
    
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
    
}

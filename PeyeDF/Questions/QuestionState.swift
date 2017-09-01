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
import GameplayKit

/// We can advance to a next question (for the GiveTopic and GivePaper states)
protocol Advanceable {
    /// Proceed to the next state (depending on the current conditions, the next state changes)
    func advance()
}

/// Subclasses keep track of the current state in the whole questionnaire.
/// We start with a GivePaper state, which assigns a paper and an associated target topic.
/// After giving a paper, we enter the familiarise state, in which we give an amount of time
/// to the participant to familiarise with the current paper (without any questions).
/// It then goes to GiveTopic, which shows a "target topic" to the participant.
/// Afterwards we go to answer question, if there are more target topics.
/// If it doesn't contain more questions, we go back to GivePaper, which gives a paper (if there are more).
/// If there are are no more papers, we go to QuestionsDone after GivePaper.
/// For a diagram, see QuestionState.key (linked in xcode)
class QuestionState: GKState {
    
    /// Waiting gets done here
    static let waitQueue = DispatchQueue(label: "peyedf.Questions.Waitqueue")
    
    /// Number of target topics for this set of questions (set when initially loading json)
    static var nOfTargetTopics = -1
    
    /// Number of questions for this set of questions (set when initially loading json)
    static var nOfQuestions = -1
    
    unowned let view: QuestionViewController
    
    init(_ associatedView: QuestionViewController) {
        view = associatedView
    }
    
}

/// Represents the state in which we assign a paper, or report that no more papers are available.
class GivePaper: QuestionState, Advanceable {
    /// List of all the papers we must ask about.
    private var papers: [Paper]
    private(set) var currentPaper: Paper?
    
    /// Number of papers done
    var papersDone = 0
    
    /// Whether the break was already completed
    var completedBreak = false
    
    /// Creates the givepaper state with an initial set of papers to give <del>(the papers will be shuffled)</del>
    init(_ associatedView: QuestionViewController, papers: [Paper]) {
        self.papers = papers
        super.init(associatedView)
    }
    
    override func didEnter(from previousState: GKState?) {
        if previousState is GiveTopic {
            papersDone += 1
        }
        if !(previousState is GivePaper) {
            currentPaper = papers.count > 0 ? papers.remove(at: 0) : nil
            view.answerSaver.writeOut()
            // if this is time for break, show it and wait
            if papersDone == QuestionConstants.nOfPapers / 2 + 1 {
                view.prepareMode(showContinue: false)
                view.showGenericMessage("You're halfway done. Please take a break now.",
                                        title: "Break time!")
                view.continueButton.isHidden = true
                DispatchQueue.main.asyncAfter(deadline: .now() + QuestionConstants.breakTime) {
                    // exit and call itself after break is done
                    self.view.continueButton.isHidden = false
                }
                return
            } else {
                view.prepareMode(showContinue: true)
            }
        }
        if let cp = currentPaper {
            
            // open document
            ((NSApplication.shared.delegate) as? AppDelegate)?.openDocument(currentPaper!.url)
            
            view.answerSaver.setCurrent(paperState: self)
            view.showGenericMessage("A new paper has been assigned",
                                    title: "New paper: \(cp.title)\n(\(cp.filename))")
            
        } else {
            view.showGenericMessage("All questions done", title: "No more questions, thanks for participating!")
        }
    }
    
    func advance() {
        // if we are on break, go into itself and return
        if stateMachine!.enter(GivePaper.self) {
            return
        }
        // if we are out of papers, go to questions done
        if !stateMachine!.enter(FamiliarisePaper.self) {
            stateMachine!.enter(QuestionsDone.self)
        }
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        if !completedBreak && papersDone == QuestionConstants.nOfPapers / 2 + 1 {
            // We allow to re-enter in case this was a break
            completedBreak = true
            return stateClass is GivePaper.Type
        } else if currentPaper != nil {
            // if there is a next paper, familiarise with it
            return stateClass is FamiliarisePaper.Type
        } else {
            // there are no more papers, we are done
            return stateClass is QuestionsDone.Type
        }
    }
}

/// Represents the state in which the user is familiarising with a paper.
/// After the allocated time is passed, automatically enters the GiveTopic phase
class FamiliarisePaper: QuestionState {
    
    fileprivate(set) var currentPaper: Paper!
    
    override func didEnter(from previousState: GKState?) {
        
        guard let ps = previousState as? GivePaper else {
            fatalError("Entered familiarise from something different than GivePaper")
        }
        
        currentPaper = ps.currentPaper!
        
        view.showGenericMessage("Please familiarise with the given paper. After a set amount of time, you will hear a sound and questions will be shown.", title: "Familiarisation")
        view.continueButton.isHidden = true
        view.moveQuestionBelow()
        
        QuestionState.waitQueue.asyncAfter(deadline: .now() + QuestionConstants.familiarizeTime) {
            __NSBeep()
            self.stateMachine!.enter(GiveTopic.self)
        }
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass is GiveTopic.Type
    }
}

/// When coming from the give paper state, initializes itself using the paper from that state.
/// Keeps track of the current question and randomises the given target topic.
class GiveTopic: QuestionState, Advanceable {

    /// Total number of target topics
    var nOfTargetTopics: Int!
    
    /// Current target topic. If this + 1 >= nOfTargetTopics are out of target topics
    private(set) var currentTtopic = Int.min
    fileprivate var questionLoader: QuestionLoader!
    
    override func didEnter(from previousState: GKState?) {
        // if we are coming from the GivePaper state, initialize
        if previousState is FamiliarisePaper {
            self.questionLoader = QuestionLoader(fromPaper: (previousState as! FamiliarisePaper).currentPaper, inDirectory: QuestionSingleton.questionsJsonLoc)
            nOfTargetTopics = self.questionLoader.nOfTtopics
            currentTtopic = -1
        }
        
        currentTtopic = currentTtopic + 1
        
        if currentTtopic >= nOfTargetTopics {
            view.showGenericMessage("Paper completed", title: "No more questions for this paper.")
            // close all open documents
            NSDocumentController.shared.documents.forEach() {
                if $0.windowControllers.count == 1 {
                    ($0.windowControllers[0] as? DocumentWindowController)?.window?.close()
                }
            }
        } else {
            let topicTitle = questionLoader.getTopicTitle(tTopicNo: currentTtopic)
            view.showGenericMessage("A new topic has been assigned.",
                                    title: "New topic: \(topicTitle)")
        }
        
        view.answerMode(false)
    }
    
    func advance() {
        if stateMachine!.enter(AnswerQuestion.self) {
        } else {
            stateMachine!.enter(GivePaper.self)
        }
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        if currentTtopic < nOfTargetTopics {
            return stateClass is AnswerQuestion.Type
        } else {
            return stateClass is GivePaper.Type
        }
    }
}

class AnswerQuestion: QuestionState {
    var currentQuestion: Int!
    var currentTtopic: Int!
    var questionLoader: QuestionLoader!
    var started: Date!
    
    override func didEnter(from previousState: GKState?) {
        if let ps = previousState as? GiveTopic {
            currentQuestion = 0
            currentTtopic = ps.currentTtopic
            questionLoader = ps.questionLoader
        } else if let ps = previousState as? AnswerQuestion {
            currentQuestion = ps.currentQuestion + 1
        } else {
            fatalError("Entered answer question from a wrong state")
        }
        view.answerSaver.setCurrent(answerState: self)
        let (question, answers, topicTitle) = questionLoader.getQuestion(qNo: currentQuestion, forTopic: currentTtopic)
        view.showQuestion(question, topic: topicTitle)
        view.showAnswers(answers)
        view.answerMode(true)
        started = Date()
        
    }
    
    func answer(_ answer: String) {
        let correct = questionLoader.isCorrect(answer: answer, forQuestion: currentQuestion, tTopic: currentTtopic)
        view.answerSaver.addAnswer(correct: correct, timePassed: Date().timeIntervalSince(started))
        if !stateMachine!.enter(AnswerQuestion.self) {
            stateMachine!.enter(GiveTopic.self)
        }
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        if currentQuestion + 1 < questionLoader.nOfQuestions {
            return stateClass is AnswerQuestion.Type
        } else {
            return stateClass is GiveTopic.Type
        }
    }
}

class QuestionsDone: QuestionState, Advanceable {
    
    override func didEnter(from previousState: GKState?) {
        // saving is done all the time when entering the givepaper state
        view.view.window!.close()
    }
    
    func advance() {
        // do nothing (window closes when entering this state)
        fatalError("Ultimate state already achieved")
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        // nothing happens after this
        return false
    }
}

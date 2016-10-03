//
//  QuestionState.swift
//  questionStateMachineTest
//
//  Created by Marco Filetti on 15/02/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation
import GameplayKit

/// We can advance to a next question (for the PrepareQuestion and GivePaper states)
protocol Advanceable {
    /// Proceed to the next state (depending on the current conditions, the next state changes)
    func advance()
}

// These classes keep track of the current state in the whole questionnaire.
// We start with a GivePaper state, which assigns a paper and an associated target topic.
// It then goes to PrepareQuestion, which shows a question to the participant.
// Afterwards we go to answer question, if PrepareQuestion contains more questions.
// If it doesn't contain more questions, we go back to GivePaper, which gives a paper (if there are more).
// If there are are no more papers, we go to QuestionsDone after GivePaper.
// State diagram:
// Questions done <-(if no more papers) GivePaper (if more papers)-> <-(if no more questions) PrepareQuestion (if more questions)-> <-(always) AnswerQuestion

class QuestionState: GKState {
    
    /// Number of target topics for this set of questions (set when initially loading json)
    static var nOfTargetTopics = -1
    
    /// Number of questions for this set of questions (set when initially loading json)
    static var nOfQuestions = -1
    
    unowned let view: QuestionViewController
    
    init(_ associatedView: QuestionViewController) {
        view = associatedView
    }
}

/// Represents the state in which we asssign a paper, or report that no more papers are available.
class GivePaper: QuestionState, Advanceable {
    /// List of all the papers we must ask about.
    private var papers: [Paper]
    private(set) var currentPaper: Paper?
    
    /// Creates the givepaper state with an initial set of papers to give <del>(the papers will be shuffled)</del>
    init(_ associatedView: QuestionViewController, papers: [Paper]) {
//        self.papers = GKRandomSource.sharedRandom().arrayByShufflingObjectsInArray(papers) as! [Paper]
        self.papers = papers
        super.init(associatedView)
    }
    
    override func didEnter(from previousState: GKState?) {
        currentPaper = papers.count > 0 ? papers.remove(at: 0) : nil
        view.answerSaver.writeOut()
        if let cp = currentPaper {
            view.answerSaver.setCurrent(paperState: self)
            view.showGenericMessage("A new paper has been assigned",
                                    title: "New paper: \(cp.title)\n(\(cp.filename))")
        } else {
            view.showGenericMessage("All questions done", title: "No more questions, thanks for participating!")
        }
    }
    
    func advance() {
        if stateMachine!.enter(PrepareQuestion.self) == false {
            stateMachine!.enter(QuestionsDone.self)
        }
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        if currentPaper != nil {
            return stateClass is PrepareQuestion.Type
        } else {
            return stateClass is QuestionsDone.Type
        }
    }
}

/// When coming from the give paper state, initializes itself using the paper from that state.
/// Keeps track of the current question and randomises the given target topic.
class PrepareQuestion: QuestionState, Advanceable {
    /// At which question we are at. One entry per target topic.
    private var questionCounts = [Int]()
    private(set) var currentQuestion: Int!
    /// Current target topic. If nil, we are out of target topics
    private(set) var currentTtopic: Int?
    fileprivate var questionLoader: QuestionLoader!
    
    /// List of all the target topics we are asking for. Fetches this one by one when entering this state.
    private var targetTopicList = [Int]()
    
    override func didEnter(from previousState: GKState?) {
        // if we are coming from the GivePaper state, initialize
        if previousState is GivePaper {
            self.questionLoader = QuestionLoader(fromPaper: (previousState as! GivePaper).currentPaper!)
            let nOfTargetTopics = self.questionLoader.nOfTtopics
            let nOfQuestions = self.questionLoader.nOfQuestions
            self.questionCounts = [Int](repeating: 0, count: nOfTargetTopics)
            let totalQuestions = nOfQuestions * nOfTargetTopics
            // if no predefined order is present, generate it
            if QuestionSingleton.questionOrder == nil {
                let rand = GKShuffledDistribution(lowestValue: 0, highestValue: nOfTargetTopics - 1)
                targetTopicList = (0..<totalQuestions).map({_ in rand.nextInt()})
            } else {
                // otherwise, fetch it from appsingleton
                targetTopicList = []
                for _ in 0..<totalQuestions {
                    let (paperNo, ttNo) = QuestionSingleton.questionOrder!.remove(at: 0)
                    if paperNo != (previousState! as! GivePaper).currentPaper!.index {
                        self.view.view.window!.close()
                        AppSingleton.alertUser("Please stop and contact experimenter", infoText: "Loaded question does not match expected question")
                        break
                    }
                    targetTopicList.append(ttNo)
                }
            }
        }
        
        // Get the next target topic (if there's any left)
        if targetTopicList.count > 0 {
            currentTtopic = targetTopicList.remove(at: 0)
        } else {
            currentTtopic = nil
        }
        
        if let ct = currentTtopic {
            currentQuestion = questionCounts[ct]
            questionCounts[ct] += 1
            view.answerSaver.setCurrent(questionState: self)
            let (question, answers, topicTitle) = questionLoader.getQuestion(qNo: currentQuestion, forTopic: ct)
            view.showQuestion(question, topic: topicTitle)
            view.showAnswers(answers)
        } else {
            view.showGenericMessage("Paper completed", title: "No more questions for this paper.")
        }
    }
    
    func advance() {
        if stateMachine!.enter(AnswerQuestion.self) {
        } else {
            stateMachine!.enter(GivePaper.self)
        }
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        if let _ = currentTtopic {
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
        guard let ps = previousState as? PrepareQuestion else {
            fatalError("Entered answer question from a wrong state")
        }
        currentTtopic = ps.currentTtopic!
        currentQuestion = ps.currentQuestion
        questionLoader = ps.questionLoader
        QuestionSingleton.answerMode()
        started = Date()
        
        // reset refider clicks and gazes
        AnswerSaver.refinderClicks = 0
        AnswerSaver.refinderFixations = []
        
    }
    
    func answer(_ answer: String) {
        let correct = questionLoader.isCorrect(answer: answer, forQuestion: currentQuestion, tTopic: currentTtopic)
        view.answerSaver.addAnswer(correct: correct, timePassed: Date().timeIntervalSince(started))
        stateMachine!.enter(PrepareQuestion.self)
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass is PrepareQuestion.Type
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

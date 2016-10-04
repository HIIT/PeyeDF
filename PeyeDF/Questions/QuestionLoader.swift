//
//  QuestionMaster.swift
//  PeyeDF
//
//  Created by Marco Filetti on 13/02/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation
import GameplayKit

enum QuestionError: Error {
    /// There are 4 questions per target topic. Asking more causes this error.
    case OutOfTopics
}

enum TargetTopicGroup: String {
    case A
    case B
}

/// Represents a paper which associated filename, code and target topic group
class Paper: NSObject {
    override var description: String { get {
        return self.code + "_" + self.group.rawValue
    } }
    
    /// Default papers
    /// - Note: Last one (index 4) is the practice paper. Note that practice only has ttg A)
    static let defaultPapers = [(code: "P1", filename: "Bener2011_asthma.pdf", title: "The Impact of Asthma and Allergic Diseases on Schoolchildren"),
                                (code: "P2", filename: "StewartEtAl2013_ClinicalPsychology.pdf", title: "Acceptability of Psychotherapy, Pharmacotherapy, and Self-Directed Therapies in Australians Living with Chronic Hepatitis C"),
                                (code: "P3", filename: "HardcastleEtAl2012_Motivational.pdf", title: "The effectiveness of a motivational interviewing primary-care based intervention"),
                                (code: "P4", filename: "Rose2012_Placebo.pdf", title: "Choice and placebo expectation effects in the context of pain analgesia"),
                                (code: "Practice", filename: "PrimackEtAl2012_Waterpipe.pdf", title: "Waterpipe Smoking Among U.S. University Students")]
    
    /// Creates a paper from a number (0 to 3) and a target topic group (A, or B)
    init(fromDefault: Int, withGroup: TargetTopicGroup) {
        code = Paper.defaultPapers[fromDefault].code
        filename = Paper.defaultPapers[fromDefault].filename
        index = fromDefault
        group = withGroup
        title = Paper.defaultPapers[fromDefault].title
    }
    
    let code: String
    let index: Int
    let filename: String
    let title: String
    let group: TargetTopicGroup
}

/// Retrieves questions saved on disk and tells us whether an answer is correct
class QuestionLoader {
    
    /// Question data
    private var json: JSON
    
    /// Number of questions (in total) for this set (using the first ttopic as a template)
    var nOfQuestions: Int { get {
        return json["ttopics"][0]["questions"].arrayObject!.count
    } }
    
    /// Number of ttopics (in total) for this set
    var nOfTtopics: Int { get {
        return json["ttopics"].arrayObject!.count
    } }
    
    /// Creates a QuestionLoader from a paper, given an url where the JSONs are located.
    /// On fail (e.g. JSON does not exist), returns nil.
    init?(fromPaper paper: Paper, inDirectory: URL) {
        guard inDirectory.quickVerify() && inDirectory.isDirectory else {
            return nil
        }
        
        let fileName = paper.code + "_\(paper.group)" + ".json"
        let questionsURL = inDirectory.appendingPathComponent(fileName)
        
        guard questionsURL.quickVerify() else {
            return nil
        }
        
        do {
            let inData = try Data(contentsOf: questionsURL)
            json = JSON(data: inData)
            
            // verify that target topic in json matches selection
            if json["ttopic_group"].stringValue != paper.group.rawValue {
                AppSingleton.alertUser("Question json target topic does not match selection")
            }
        } catch {
            AppSingleton.log.error("Failed to load questions: \(error)")
            return nil
        }
    }
    
    /// Retrieves given question number for the given target topic number.
    func getQuestion(qNo: Int, forTopic: Int) -> (question: String, answers: [String], topicTitle: String) {
        let question: String = json["ttopics"][forTopic]["questions"][qNo]["question"].stringValue
        let answers: [String] = json["ttopics"][forTopic]["questions"][qNo]["answers"].arrayObject! as! [String]
        let topicTitle: String = json["ttopics"][forTopic]["title"].stringValue
        
        return (question, answers, topicTitle)
    }
    
    /// Tellls whether a given question is correct
    func isCorrect(answer: String, forQuestion: Int, tTopic: Int) -> Bool {
        return json["ttopics"][tTopic]["questions"][forQuestion]["answers"][0].stringValue == answer
    }
}

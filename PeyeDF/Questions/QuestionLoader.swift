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

import Foundation
import GameplayKit
import os.log

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
            if #available(OSX 10.12, *) {
                os_log("Failed to load questions: %@", type: .error, error.localizedDescription)
            }
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
    
    /// Retrieves current target topic title.
    func getTopicTitle(tTopicNo: Int) -> String {
        return json["ttopics"][tTopicNo]["title"].stringValue
    }
    
    /// Tellls whether a given question is correct
    func isCorrect(answer: String, forQuestion: Int, tTopic: Int) -> Bool {
        return json["ttopics"][tTopic]["questions"][forQuestion]["answers"][0].stringValue == answer
    }
}

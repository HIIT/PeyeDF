//
//  AnswerSaver.swift
//  PeyeDF
//
//  Created by Marco Filetti on 16/02/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation

/// Keeps track of all the answers given, their time, and saves to json
class AnswerSaver {
    
    var currentPaperCode: String!
    var currentPaperIndex: Int!
    var currentQuestion: Int!
    var currentTopic: Int!
    var currentGroup: TargetTopicGroup!
    
    var answers = [[String: Any]]()
    let pNo: Int
    
    init(pNo: Int) {
        self.pNo = pNo
    }
    
    func setCurrent(paperState: GivePaper) {
        self.currentPaperCode = paperState.currentPaper!.code
        self.currentPaperIndex = paperState.currentPaper!.index
        self.currentGroup = paperState.currentPaper!.group
    }
    
    func setCurrent(answerState: AnswerQuestion) {
        self.currentTopic = answerState.currentTtopic!
        self.currentQuestion = answerState.currentQuestion!
    }
    
    func addAnswer(correct: Bool, timePassed: Double) {
        var newVal = [String: Any]()
        newVal["paper"] = currentPaperIndex
        newVal["paperCode"] = currentPaperCode
        newVal["questionNo"] = currentQuestion
        newVal["ttopicNo"] = currentTopic
        newVal["ttopicGroup"] = currentGroup.rawValue
        newVal["correct"] = correct
        newVal["timePassed"] = timePassed
        
        answers.append(newVal)
    }
    
    /// Save own contents to json, in the format P##_datetime
    func writeOut() {
        let pString = String(format: "%02d", pNo)
        var outObject = [String: Any]()
        outObject["pNo"] = pNo
        outObject["timeTaken"] = QuestionSingleton.timeTaken
        outObject["answers"] = answers
        
        let dateFormat = "d'-'MM'-'d'_'HH'.'mm'.'ss"  // date format for output file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormat
        let dateString = dateFormatter.string(from: Date())
        
        let outFileName = "\(pString)_\(dateString)"
        
        let outputDirectory = QuestionSingleton.outputJsonLoc
        
        let jsonFile = outputDirectory.appendingPathComponent("\(outFileName).json")
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        // creating a .json file in the folder
        if fileManager.fileExists(atPath: jsonFile.path, isDirectory: &isDirectory) {
            fatalError("Output json already exists (shouldn't happen since we use timestamps)")
        }
        
        // creating JSON out of the above array
        var jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: outObject, options: JSONSerialization.WritingOptions.prettyPrinted)
            try jsonData.write(to: jsonFile)
        } catch {
            fatalError("Failed to serialize json / write data: \(error)")
        }
        
    }
    
}

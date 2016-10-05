//
//  QuestionsSingleton.swift
//  PeyeDF
//
//  Created by Marco Filetti on 03/10/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation
import Cocoa

/// Stores information for an experimental session.
/// The PeyeDF Questions App is expected to terminate at the end of a successful session.
class QuestionSingleton {
    
    // MARK: - Constants
    
    static let baseUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Peyexperiment")
    
    // MARK: - Folder locations
    
    /// Location of the JSON files that contain information about papers (questions)
    static var questionsJsonLoc = baseUrl.appendingPathComponent("Questions")
    
    /// Location of the JSON files that contain information on the sequence of questions we are asking
    static var partJsonLoc = baseUrl.appendingPathComponent("Participants")
    
    /// Location of the PDF documents
    static var experimentPdfsLoc = baseUrl.appendingPathComponent("PDFs")
    
    // Output JSONs will be outputted here
    static var outputJsonLoc = baseUrl.appendingPathComponent("Outputs")
    
    /// This enum represents a folder location (which contain experiment files).
    /// The Int representation is used to refer to a tag in Experiment preferences.
    enum FolderLocation: Int {
        case inputQuestions = 1
        case inputParticipant = 2
        case pdfDocuments = 3
        case output = 4
        
        var url: URL { get {
            switch self {
            case .inputQuestions:
                return questionsJsonLoc
            case .inputParticipant:
                return partJsonLoc
            case .pdfDocuments:
                return experimentPdfsLoc
            case .output:
                return outputJsonLoc
            }
        } }
    }

    // MARK: - Experiment-related Variables
    
    static var questionWindow: NSWindowController!
    static var paperOrder = [Paper]() // papers will be added from input json after it is loaded

    static var docWindowController: NSWindowController? // TODO: change this to doc window
    static var questionController: QuestionViewController? // TODO: change this (set)
    
    /// Participant number (defaults to infinity, should be changed on app start)
    static var pNo = Int.max
    
    static let questionsStoryboard = NSStoryboard(name: "Questions", bundle: nil)
    
    /// Seconds taken to read each apper
    static var timeTaken = [Double]()
    
    /// Arranges windows to receive answers
    static func answerMode() {
        let qframe = moveQuestionBelow()
        questionController?.answerMode(ownFrame: qframe!)
    }
    
    /// Puts the document's window above the question, with a smaller question window below
    /// returns question frame rect
    static func moveQuestionBelow() -> NSRect? {
        guard let winc = docWindowController, let win = winc.window, let mainS = NSScreen.main() else {
            return nil
        }
        
        var reducedScreenFrame = mainS.visibleFrame
        reducedScreenFrame.size.height -= 300
        reducedScreenFrame.origin.y += 300
        win.setFrame(reducedScreenFrame, display: true, animate: true)
        
        var questionFrame = mainS.visibleFrame
        questionFrame.size.height = 300
        questionFrame.size.width -= 100
        questionFrame.origin.x += 50
        return questionFrame
    }
    
    /// Attempts to load all data needed to run the experiment.
    ///
    /// - returns: Returns a boolean indicating whether loaded succeeded and a list of **failed** locations. That is, if the operation
    /// was successful, returns an empty list and true.
    static func loadData(partNo: Int, newQuestionsPath: String, newPartPath: String, newPdfLoc: String, newOutputPath: String) -> (success: Bool, failed: [FolderLocation]) {
        var failedLocations = [FolderLocation]()
        
        if !verifyQuestions(newUrl: URL(fileURLWithPath: newQuestionsPath)) {
            failedLocations.append(.inputQuestions)
        }
        
        if !verifyPDFs(newUrl: URL(fileURLWithPath: newPdfLoc)) {
            failedLocations.append(.pdfDocuments)
        }

        if !verifyOutput(newUrl: URL(fileURLWithPath: newOutputPath)) {
            failedLocations.append(.output)
        }
        
        guard let partJsonUrl = verifyParticipant(forPno: partNo, inDirectory: URL(fileURLWithPath: newPartPath)) else {
            failedLocations.append(.inputParticipant)
            return (false, failedLocations)
        }


        // finally check that loaded pNo in json corresponds to pNo we have.
        // alert user if not, othewise load data and return true
        do {
            let inData = try Data(contentsOf: partJsonUrl)
            let json = JSON(data: inData)
            
            guard json["pNo"].intValue == partNo else {
                AppSingleton.alertUser("Participant number in json different than expected")
                return (false, failedLocations)
            }
            
            // create ordering
            paperOrder = [Paper]()
            // first one is practice paper
            paperOrder.append(Paper(fromDefault: 4, withGroup: .A))
            // append assignments in order
            for assignment in json["assignments"].arrayValue {
                let papNum = assignment["paper"].intValue
                let tgroup = assignment["ttopicGroup"].stringValue
                let newPaper = Paper(fromDefault: papNum, withGroup: TargetTopicGroup(rawValue: tgroup)!)
                paperOrder.append(newPaper)
            }
            
        } catch {
            AppSingleton.alertUser("Failed to read input data")
            return (false, failedLocations)
        }
        
        if failedLocations.count == 0 {
            return (true, failedLocations)
        } else {
            return (false, failedLocations)
        }
        
    }
    
    /// Start the question loop. Returns true on success.
    static func startQuestions() -> Bool {
        
        // make sure there are no documents currently open
        guard NSDocumentController.shared().documents.count == 0 else {
            AppSingleton.alertUser("There are open documents")
            return false
        }
        
        questionWindow = (QuestionSingleton.questionsStoryboard.instantiateController(withIdentifier: "QuestionWindowController") as! NSWindowController)
        questionWindow.showWindow(nil)
        // comment these two below for debugging, so you can see behind
        questionWindow.window?.level = Int(CGWindowLevelForKey(.floatingWindow))
        questionWindow.window?.level = Int(CGWindowLevelForKey(.maximumWindow))
        questionController = (questionWindow.contentViewController as! QuestionViewController)
        questionController!.begin(withPapers: paperOrder)

        return true
    }
    
    // MARK: - Notification callbacks
    
    @objc static func documentChanged(notification: NSNotification) {
        if notification.name == PeyeConstants.documentChangeNotification {
            // associate the window variable to the last document that was opened
            if let doc = notification.object as? NSDocument {
                docWindowController = doc.windowControllers[0] as! DocumentWindowController
            }
        }
    }
    
    // MARK: - Helper for input data validation
    
    /// Attempts to load the questions for this participant (using the pno static var).
    /// Sets the paperOrder static variable (and optionally the new url, if given).
    /// Returns true if the questions were successfully loaded.
    static func verifyQuestions(newUrl: URL? = nil) -> Bool {
        let urlToVerify: URL
        if newUrl == nil {
            urlToVerify = questionsJsonLoc
        } else {
            urlToVerify = newUrl!
        }
        
        guard urlToVerify.quickVerify() && urlToVerify.isDirectory else {
            return false
        }
        
        
        // Make sure all papers we need to open are loadable
        for (n, _) in Paper.defaultPapers.enumerated() {
            let paper = Paper(fromDefault: n, withGroup: .A)
            if QuestionLoader(fromPaper: paper, inDirectory: urlToVerify) == nil {
                return false
            }
        }
        
        questionsJsonLoc = urlToVerify
        return true
    }
    
    /// Returns an URL pointing to the questions for this participant number.
    /// Sets the pNo static variable accordingly.
    /// A new url can be given (inDirectory) which will override the current value.
    /// Returns nil if the operation failed.
    static func verifyParticipant(forPno pNo: Int, inDirectory: URL? = nil) -> URL? {
        let urlToVerify: URL
        if inDirectory == nil {
            urlToVerify = partJsonLoc
        } else {
            urlToVerify = inDirectory!
        }

        QuestionSingleton.pNo = pNo
        let fileString = String(format: "P%02d.json", pNo)
        let fileUrl = urlToVerify.appendingPathComponent(fileString)
        
        if fileUrl.quickVerify() {
            partJsonLoc = urlToVerify
            return fileUrl
        } else {
            return nil
        }
    }
    
    /// Attempts to load the questions for this participant.
    /// (Optionally sets the new url, if given).
    /// Returns true if all needed pdfs can be loaded.
    static func verifyPDFs(newUrl: URL? = nil) -> Bool {
        let urlToVerify: URL
        if newUrl == nil {
            urlToVerify = experimentPdfsLoc
        } else {
            urlToVerify = newUrl!
        }
        
        guard urlToVerify.quickVerify() && urlToVerify.isDirectory else {
            return false
        }

        for paper in Paper.defaultPapers {
            if urlToVerify.appendingPathComponent(paper.filename).quickVerify() == false {
                return false
            }
        }
        experimentPdfsLoc = urlToVerify
        return true
    }
    
    /// Returns true if the output folder can be accessed.
    /// Optionally sets the new url, if given.
    static func verifyOutput(newUrl: URL? = nil) -> Bool {
        let urlToVerify: URL
        if newUrl == nil {
            urlToVerify = outputJsonLoc
        } else {
            urlToVerify = newUrl!
        }
        
        if urlToVerify.quickVerify() && urlToVerify.isDirectory {
            return true
        } else {
            return false
        }
    }
}

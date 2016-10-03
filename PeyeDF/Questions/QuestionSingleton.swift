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

    static var questionWindow: NSWindowController!
    static var papers = [Paper]() // papers will be added from input json after it is loaded

    // default name of data directory
    static let dataDirName = "Peyexperiment"
    
    static var theWindowController: NSWindowController? // TODO: change this to doc window
    static var _dawindow: NSWindowController? // TODO: this should be the doc's window
    static var questionController: QuestionViewController? // TODO: change this (set)
    
    /// Participant number (defaults to 999, change it when known)
    static var pNo = 999
    
    static let questionsStoryboard = NSStoryboard(name: "Questions", bundle: nil)
    
    /// Seconds taken to read each apper
    static var timeTaken = [Double]()
    
    /// Whether we are in question mode
    static var questionMode = true
    
    /// The order of questions (or more specifically the order of target topics) will be pre-loaded from the input file, instead of being randomly generated if we want so (otherwise will be nil)
    static var questionOrder: [(paper: Int, ttopicNo: Int)]? = nil
    
    /// Arranges windows to receive answers
    static func answerMode() {
        let qframe = refinderAboveQuestionBelow()
        questionController?.answerMode(ownFrame: qframe!)
    }
    
    /// Puts the refinder above question, with a smaller question window below
    /// returns question frame rect
    static func refinderAboveQuestionBelow() -> NSRect? {
        guard let winc = theWindowController, let win = winc.window, let mainS = NSScreen.main() else {
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
    
    /// Prepares to start, initializes all fields
    static func prepare() {
        // get experiment file (must run on main thread)
        DispatchQueue.main.async {
            var fileURL: URL?
            var inData: Data?
            repeat {
                fileURL = getInitialFileURL()
                if fileURL != nil {
                    inData = try! Data(contentsOf: fileURL!)
                }
            } while fileURL == nil || inData == nil
            do {
                // read json data and put in relevant places
                let jsonData = try JSONSerialization.jsonObject(with: inData!, options: .allowFragments) as! [String: AnyObject]
                let json = JSON(jsonData)
                QuestionSingleton.pNo = json["pNo"].intValue
                // first one is practice apper
                QuestionSingleton.papers.append(Paper(fromDefault: 4, withGroup: .A))
                // append assignments in order
                for assignment in json["assignments"].arrayValue {
                    let papNum = assignment["paper"].intValue
                    let tgroup = assignment["ttopicGroup"].stringValue
                    let newPaper = Paper(fromDefault: papNum, withGroup: TargetTopicGroup(rawValue: tgroup)!)
                    QuestionSingleton.papers.append(newPaper)
                }
            } catch {
                AppSingleton.alertUser("Can't read json", infoText: "\(error)")
            }
        }

    }
    
    /// Start the question loop
    static func startQuestions() {
        if QuestionSingleton.questionMode && _dawindow != nil {
            _dawindow!.showWindow(self)
            questionWindow = (QuestionSingleton.questionsStoryboard.instantiateController(withIdentifier: "QuestionWindowController") as! NSWindowController)
            questionWindow.showWindow(nil)
            // MF: comment these two below for debugging
            questionWindow.window?.level = Int(CGWindowLevelForKey(.floatingWindow))
            questionWindow.window?.level = Int(CGWindowLevelForKey(.maximumWindow))
            questionController = (questionWindow.contentViewController as! QuestionViewController)
            questionController!.begin(withPapers: papers)
            // copy times taken to app singleton
            DiMeFetcher.fetchPeyeDFEvents(getSummaries: true, sessionId: nil) {
                json in
                guard let summaries = json?.array else {
                    AppSingleton.alertUser("Could not find any summary event")
                    return
                }
                
                let timeTaken = summaries.map({$0["readingTime"].doubleValue})
                
                if timeTaken.count != 5 {
                    AppSingleton.alertUser("Note: number of summaries is different than five")
                }
                QuestionSingleton.timeTaken = timeTaken
            }
        }
    }

    /// Asks what is the file path and subject number, and returns an URL corresponding to the
    /// json with the relevant settings
    static func getInitialFileURL() -> URL? {
        
        let viewSize: CGFloat = 600
        let viewH: CGFloat = 100
        let textH: CGFloat = 24
        let textW: CGFloat = 390
        
        // file dir
        let docUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dataUrl = docUrl.appendingPathComponent(QuestionSingleton.dataDirName)
        
        let msg = NSAlert()
        msg.addButton(withTitle: "OK")      // 1st button
        msg.addButton(withTitle: "Cancel")  // 2nd button
        msg.messageText = "Input"
        msg.informativeText = "Directory and participant number"
        
        let view = NSView(frame: NSRect(origin: NSPoint(), size: NSSize(width: viewSize, height: viewH)))
        
        let txt1 = NSTextField(frame: NSRect(x: 0, y: textH*3, width: textW, height: textH))
        txt1.placeholderString = "##"
        view.addSubview(txt1)
        
        let txt2 = NSTextField(frame: NSRect(x: 0, y: textH*2, width: textW, height: textH))
        txt2.stringValue = dataUrl.absoluteString
        view.addSubview(txt2)
        
        let butt = NSButton(frame: NSRect(x: 0, y: 0, width: 90, height: textH))
        butt.setButtonType(.switch)
        butt.state = NSOffState
        butt.title = "Pre-load"
        view.addSubview(butt)
        
        msg.accessoryView = view
        let response: NSModalResponse = msg.runModal()
        
        if (response == NSAlertFirstButtonReturn) {
            guard let pNo = Int((view.subviews[0] as! NSTextField).stringValue) else {
                return nil
            }
            QuestionSingleton.pNo = pNo
            let dir = (view.subviews[1] as! NSTextField).stringValue
            let fileS = String(format: "P%02d", pNo)
            let dirUrl = NSURL(fileURLWithPath: dir, isDirectory: true)
            let fileURL = dirUrl.appendingPathComponent(fileS + ".json")
            // set pre-load order, if we want so
            if (view.subviews[2] as! NSButton).state == NSOnState {
                do {
                    let orderData = try Data(contentsOf: fileURL!)
                    do {
                        let inJson = try JSONSerialization.jsonObject(with: orderData, options: .allowFragments) as! [String: Any]
                        if let orderJson = inJson["questionList"] as? [[String: Any]] {
                            QuestionSingleton.questionOrder = [(paper: Int, ttopicNo: Int)]()
                            orderJson.forEach() {
                                QuestionSingleton.questionOrder?.append((paper: $0["paper"] as! Int, ttopicNo: $0["ttopicNo"] as! Int))
                            }
                        } else {
                            AppSingleton.alertUser("Could not find “questionList”")
                        }
                    } catch {
                        AppSingleton.alertUser("Could not convert question data from json", infoText: "\(error)")
                    }
                } catch {
                    AppSingleton.alertUser("Could not load question data")
                }
            }
            return fileURL
        } else {
            NSApplication.shared().terminate(self)
            return nil
        }
    }
    
}

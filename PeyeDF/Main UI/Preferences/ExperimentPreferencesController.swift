//
//  ExperimentPreferencesController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 28/09/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Cocoa

class ExperimentPreferencesController: NSViewController {
    
    // MARK: - Common
    
    /// Enabled only if we are in questions mode, has high priority
    @IBOutlet weak var questionsBottomConstraint: NSLayoutConstraint!
    
    /// Is always enabled, but has lower priority than questionsBottomConstraint
    @IBOutlet weak var normalBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var showJsonMenusCell: NSButtonCell!
    
    @IBOutlet weak var leftDomEyeButton: NSButton!
    @IBOutlet weak var rightDomEyeButton: NSButton!
    
    @IBOutlet weak var dpiField: NSTextField!  // is second item when questions are off
    @IBOutlet weak var eyeTrackerCell: NSButtonCell!

    /// Hidden if we are not in the Questions target
    @IBOutlet weak var questionBox: NSBox!
    
    /// Action responding to left or right dominant eye selection
    @IBAction func dominantButtonPress(_ sender: NSButton) {
        if sender.identifier! == "leftDomEyeButton" {
            UserDefaults.standard.setValue(Eye.left.rawValue, forKey: PeyeConstants.prefDominantEye)
            MidasManager.sharedInstance.setDominantEye(.left)
        } else if sender.identifier! == "rightDomEyeButton" {
            UserDefaults.standard.setValue(Eye.right.rawValue, forKey: PeyeConstants.prefDominantEye)
            MidasManager.sharedInstance.setDominantEye(.right)
        } else {
            fatalError("Some unrecognized button was pressed!?")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set dominant eye button pressed accordingly to current preference
        let rawEyePreference = UserDefaults.standard.value(forKey: PeyeConstants.prefDominantEye) as! Int
        
        let eyePreference = Eye(rawValue: rawEyePreference)
        
        if eyePreference == .left {
            leftDomEyeButton.state = NSOnState
        } else {
            rightDomEyeButton.state = NSOnState
        }
        
        // number formatter for dpi
        let intFormatter = NumberFormatter()
        intFormatter.numberStyle = NumberFormatter.Style.decimal
        intFormatter.allowsFloats = false
        intFormatter.minimum = 0
        dpiField.formatter = intFormatter
        
        let options: [String: AnyObject] = ["NSContinuouslyUpdatesValue": true as AnyObject]
        
        showJsonMenusCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefShowJsonMenus, options: options)

        dpiField.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefMonitorDPI, options: options)
        eyeTrackerCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefUseEyeTracker, options: options)
        
        // MARK: - "Questions" target
        
        #if QUESTIONS
            questionBox.isHidden = false
            partNoLabel.formatter = intFormatter
            questionsBottomConstraint.isActive = true
            inputQuestionsLoc.stringValue = QuestionSingleton.questionsJsonLoc.path
            inputPartLoc.stringValue = QuestionSingleton.partJsonLoc.path
            pdfLoc.stringValue = QuestionSingleton.experimentPdfsLoc.path
            outputLoc.stringValue = QuestionSingleton.outputJsonLoc.path
        #else
            questionBox.isHidden = true
            questionsBottomConstraint.isActive = false
        #endif
    }
    
    // MARK: - "Questions" target text fields
    
    // Note: we use IB tags to discriminate between items in the questions box
    
    /// Participant number label (tag: 10)
    @IBOutlet weak var partNoLabel: NSTextField!
    
    /// Input questions (papers and their questions) json (tag: 1)
    @IBOutlet weak var inputQuestionsLoc: NSTextField!
    
    /// Input participant jsons (tag: 2)
    @IBOutlet weak var inputPartLoc: NSTextField!
    
    /// PDFs folder location (tag: 3)
    @IBOutlet weak var pdfLoc: NSTextField!
    
    /// Output jsons loc (tag: 4)
    @IBOutlet weak var outputLoc: NSTextField!
    
    /// When the data has been reloaded successfully, this shows for one second.
    /// If data reload failed it is shown red and stays there.
    @IBOutlet weak var dataReloadedLabel: NSTextField!
    
    func fieldFor(location: QuestionSingleton.FolderLocation) -> NSTextField {
        switch location {
        case .inputQuestions:
            return inputQuestionsLoc
        case .inputParticipant:
            return inputPartLoc
        case .pdfDocuments:
            return pdfLoc
        case .output:
            return outputLoc
        }
    }
    
    // MARK: - Locations and colours
    
    /// Sets all location text fields to green-ish, to signal they are correct
    func setAllGood() {
        let allFields = [inputQuestionsLoc, inputPartLoc, pdfLoc, outputLoc]
        DispatchQueue.main.async {
            allFields.forEach() {
                $0?.backgroundColor = #colorLiteral(red: 0.721568644, green: 0.8862745166, blue: 0.5921568871, alpha: 1)
            }
        }
    }
    
    /// Verifies that the given location can be loaded, sets color to red-ish if location
    /// fails.
    @IBAction func verifyLocations(_ sender: AnyObject) {
        guard let partNo = Int(partNoLabel.stringValue) else {
            AppSingleton.alertUser("Failed to parse participant number")
            return
        }
        
        setAllGood()
        
        let loadResult = QuestionSingleton.loadData(partNo: partNo, newQuestionsPath: inputQuestionsLoc.stringValue, newPartPath: inputPartLoc.stringValue, newPdfLoc: pdfLoc.stringValue, newOutputPath: outputLoc.stringValue)
        
        for f in loadResult.failed {
            DispatchQueue.main.async {
                self.fieldFor(location: f).backgroundColor = #colorLiteral(red: 0.9568627477, green: 0.6588235497, blue: 0.5450980663, alpha: 1)
            }
        }
        
        if loadResult.success {
            DispatchQueue.main.async {
                self.dataReloadedLabel.isHidden = false
                self.dataReloadedLabel.textColor = NSColor.black
                self.dataReloadedLabel.stringValue = "Data reloaded"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.dataReloadedLabel.isHidden = true
                }
            }
        } else {
            DispatchQueue.main.async {
                self.dataReloadedLabel.isHidden = false
                self.dataReloadedLabel.textColor = NSColor.red
                self.dataReloadedLabel.stringValue = "Load failed"
            }
        }
    }
    
    
    // MARK: - Browse action
    
    @IBAction func browsePress(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.directoryURL = QuestionSingleton.FolderLocation(rawValue: sender.tag)!.url
        
        guard let win = self.view.window else {
            AppSingleton.log.error("Failed to get window")
            return
        }
        
        openPanel.beginSheetModal(for: win) {
            if $0 == NSFileHandlingPanelOKButton, let url = openPanel.url {
                DispatchQueue.main.async {
                    let loc = QuestionSingleton.FolderLocation(rawValue: sender.tag)!
                    self.fieldFor(location: loc).stringValue = url.path
                    self.verifyLocations(self)
                }
            }
        }
    }
    
}

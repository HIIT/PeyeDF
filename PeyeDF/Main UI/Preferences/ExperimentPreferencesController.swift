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

import Cocoa

class ExperimentPreferencesController: NSViewController {
    
    // MARK: - Common
    
    /// Enabled only if we are in questions mode, has high priority
    @IBOutlet weak var questionsBottomConstraint: NSLayoutConstraint!
    
    /// Is always enabled, but has lower priority than questionsBottomConstraint
    @IBOutlet weak var normalBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var showJsonMenusCell: NSButtonCell!
    
    @IBOutlet weak var eyeTrackerPopUp: NSPopUpButton!
    @IBOutlet weak var leftDomEyeButton: NSButton!
    @IBOutlet weak var rightDomEyeButton: NSButton!
    
    @IBOutlet weak var dpiField: NSTextField!  // is second item when questions are off

    /// Hidden if we are not in the Questions target
    @IBOutlet weak var questionBox: NSBox!
    
    /// Action responding to left or right dominant eye selection
    @IBAction func dominantButtonPress(_ sender: NSButton) {
        if sender.identifier!.rawValue == "leftDomEyeButton" {
            AppSingleton.dominantEye = .left
        } else if sender.identifier!.rawValue == "rightDomEyeButton" {
            AppSingleton.dominantEye = .right
        } else {
            fatalError("Some unrecognized button was pressed!?")
        }
    }
    
    @IBAction func eyeTrackerSelection(_ sender: NSMenuItem) {
        guard let selectedTrackerType = EyeDataProviderType(rawValue: sender.tag) else {
            return
        }
        
        let oldTrackerPref = UserDefaults.standard.object(forKey: PeyeConstants.prefEyeTrackerType) as! Int
        
        if oldTrackerPref != sender.tag {
            UserDefaults.standard.set(sender.tag, forKey: PeyeConstants.prefEyeTrackerType)
            AppSingleton.eyeTracker = selectedTrackerType.associatedTracker
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create eye tracker selection menu items using the EyeDataProviderType enum
        // and setting the corresponding rawValue to the created item's tag
        for i in 0..<EyeDataProviderType.count {
            let tracker = EyeDataProviderType(rawValue: i)!
            let menuItem = NSMenuItem(title: tracker.description, action: #selector(self.eyeTrackerSelection(_:)), keyEquivalent: "")
            menuItem.tag = i
            eyeTrackerPopUp.menu!.addItem(menuItem)
        }
        
        // select correct menu item
        if let storedTrackerPref = UserDefaults.standard.object(forKey: PeyeConstants.prefEyeTrackerType) as? Int {
            eyeTrackerPopUp.select(eyeTrackerPopUp.itemArray[storedTrackerPref])
        }
        
        if AppSingleton.dominantEye == .left {
            leftDomEyeButton.state = .on
        } else {
            rightDomEyeButton.state = .on
        }
        
        // number formatter for dpi
        let intFormatter = NumberFormatter()
        intFormatter.numberStyle = NumberFormatter.Style.decimal
        intFormatter.allowsFloats = false
        intFormatter.minimum = 0
        dpiField.formatter = intFormatter
        
        let options = [NSBindingOption.continuouslyUpdatesValue: true]
        
        showJsonMenusCell.bind(NSBindingName(rawValue: "value"), to: NSUserDefaultsController.shared, withKeyPath: "values." + PeyeConstants.prefShowJsonMenus, options: options)

        dpiField.bind(NSBindingName(rawValue: "value"), to: NSUserDefaultsController.shared, withKeyPath: "values." + PeyeConstants.prefMonitorDPI, options: options)
        
        // MARK: - "Questions" target
        
        #if QUESTIONS
            questionBox.isHidden = false
            partNoLabel.formatter = intFormatter
            questionsBottomConstraint.isActive = true
            
            // load default paths
            inputQuestionsLoc.stringValue = QuestionSingleton.questionsJsonLoc.path
            inputPartLoc.stringValue = QuestionSingleton.partJsonLoc.path
            pdfLoc.stringValue = QuestionSingleton.experimentPdfsLoc.path
            outputLoc.stringValue = QuestionSingleton.outputJsonLoc.path
        #else
            questionBox.isHidden = true
            questionsBottomConstraint.isActive = false
        #endif
    }
    
    // MARK: - "Questions" outlets and actions
    
    
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
    
    /// The start button is enabled when everything is loaded correctly
    @IBOutlet weak var startButton: NSButton!
    
    #if QUESTIONS
    
    /// Return the text field corresponding to the desired location
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
    
    #endif
    
    /// Verifies that the given location can be loaded, sets color to red-ish if location
    /// fails.
    @IBAction func verifyLocations(_ sender: AnyObject) {
        #if QUESTIONS
        
        guard let partNo = Int(partNoLabel.stringValue) else {
            AppSingleton.alertUser("Failed to parse participant number")
            return
        }
        
        setAllGood()
        
        let loadResult = QuestionSingleton.loadData(partNo: partNo, newQuestionsPath: inputQuestionsLoc.stringValue, newPartPath: inputPartLoc.stringValue, newPdfLoc: pdfLoc.stringValue, newOutputPath: outputLoc.stringValue)
        
        // Make failed paths red
        for f in loadResult.failed {
            DispatchQueue.main.async {
                self.fieldFor(location: f).backgroundColor = #colorLiteral(red: 0.9568627477, green: 0.6588235497, blue: 0.5450980663, alpha: 1)
            }
        }
        
        // Enable button on success
        DispatchQueue.main.async {
            self.startButton.isEnabled = loadResult.success
        }
        
        // On success, show black label.
        // On fail, permanently show red label.
        if loadResult.success {
            DispatchQueue.main.async {
                self.dataReloadedLabel.isHidden = false
                self.dataReloadedLabel.textColor = NSColor.black
                self.dataReloadedLabel.stringValue = "Data reloaded"
            }
        } else {
            DispatchQueue.main.async {
                self.dataReloadedLabel.isHidden = false
                self.dataReloadedLabel.textColor = NSColor.red
                self.dataReloadedLabel.stringValue = "Load failed"
            }
        }
        
        #endif
    }
    
    // MARK: - Start action
    
    /// Start the questions, loading needed files and presenting user with questions.
    /// - Attention: It will attempt to close all windows but if the current open document
    ///   is the same as the first one of the experiment it will cause a freeze.
    @IBAction func startQuestions(_ sender: AnyObject) {
        #if QUESTIONS
        
        (sender as? NSButton)?.isEnabled = false
        self.view.window?.close()
        QuestionSingleton.startQuestions()
        
        #endif
    }
    
    // MARK: - Browse action
    
    /// When we browse, use the tag to identify which field we are editing.
    /// Verify locations on ok button press.
    @IBAction func browsePress(_ sender: NSButton) {
        #if QUESTIONS
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.directoryURL = QuestionSingleton.FolderLocation(rawValue: sender.tag)!.url
        
        guard let win = self.view.window else {
            return
        }
        
        openPanel.beginSheetModal(for: win) {
            if $0.rawValue == NSFileHandlingPanelOKButton, let url = openPanel.url {
                DispatchQueue.main.async {
                    let loc = QuestionSingleton.FolderLocation(rawValue: sender.tag)!
                    self.fieldFor(location: loc).stringValue = url.path
                    self.verifyLocations(self)
                }
            }
        }
        
        #endif
    }
    
}

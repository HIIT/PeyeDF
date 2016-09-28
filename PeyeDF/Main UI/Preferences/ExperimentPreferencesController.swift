//
//  ExperimentPreferencesController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 28/09/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Cocoa

class ExperimentPreferencesController: NSViewController {
    
    @IBOutlet weak var showJsonMenusCell: NSButtonCell!
    
    @IBOutlet weak var leftDomEyeButton: NSButton!
    @IBOutlet weak var rightDomEyeButton: NSButton!
    
    @IBOutlet weak var dpiField: NSTextField!
    @IBOutlet weak var eyeTrackerCell: NSButtonCell!

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
        dpiField.formatter = intFormatter

        

        let options: [String: AnyObject] = ["NSContinuouslyUpdatesValue": true as AnyObject]
        
        showJsonMenusCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefShowJsonMenus, options: options)

        dpiField.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefMonitorDPI, options: options)
        eyeTrackerCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefUseEyeTracker, options: options)
    }
    
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
}

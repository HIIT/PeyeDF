//
//  GeneralSettingsController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 03/09/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa

class GeneralSettingsController: NSViewController {
    
    @IBOutlet weak var leftDomEyeButton: NSButton!
    @IBOutlet weak var rightDomEyeButton: NSButton!
    
    @IBOutlet weak var annotateDefaultOnCell: NSButtonCell!
    @IBOutlet weak var dpiField: NSTextField!
    @IBOutlet weak var thicknessField: NSTextField!
    @IBOutlet weak var thicknessSlider: NSSlider!
    @IBOutlet weak var midasCheckCell: NSButtonCell!
    @IBOutlet weak var refinderDrawGazedCheckCell: NSButtonCell!
    @IBOutlet weak var drawDebugCircleCheckCell: NSButtonCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set dominant eye button pressed accordingly to current preference
        let rawEyePreference = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDominantEye) as! Int
        
        let eyePreference = Eye(rawValue: rawEyePreference)
        
        if eyePreference == .left {
            leftDomEyeButton.state = NSOnState
        } else {
            rightDomEyeButton.state = NSOnState
        }
        
        let floatFormatter = NSNumberFormatter()
        floatFormatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
        floatFormatter.allowsFloats = true
        thicknessField.formatter = floatFormatter
        
        let intFormatter = NSNumberFormatter()
        intFormatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
        intFormatter.allowsFloats = false
        dpiField.formatter = intFormatter
        
        let options: [String: AnyObject] = ["NSContinuouslyUpdatesValue": true]
        
        dpiField.bind("value", toObject: NSUserDefaultsController.sharedUserDefaultsController(), withKeyPath: "values." + PeyeConstants.prefMonitorDPI, options: options)
        
        thicknessSlider.bind("value", toObject: NSUserDefaultsController.sharedUserDefaultsController(), withKeyPath: "values." + PeyeConstants.prefAnnotationLineThickness, options: options)
        thicknessField.bind("value", toObject: NSUserDefaultsController.sharedUserDefaultsController(), withKeyPath: "values." + PeyeConstants.prefAnnotationLineThickness, options: options)
        
        
        annotateDefaultOnCell.bind("value", toObject: NSUserDefaultsController.sharedUserDefaultsController(), withKeyPath: "values." + PeyeConstants.prefEnableAnnotate, options: options)
        midasCheckCell.bind("value", toObject: NSUserDefaultsController.sharedUserDefaultsController(), withKeyPath: "values." + PeyeConstants.prefUseMidas, options: options)
        refinderDrawGazedCheckCell.bind("value", toObject: NSUserDefaultsController.sharedUserDefaultsController(), withKeyPath: "values." + PeyeConstants.prefRefinderDrawGazedUpon, options: options)
        drawDebugCircleCheckCell.bind("value", toObject: NSUserDefaultsController.sharedUserDefaultsController(), withKeyPath: "values." + PeyeConstants.prefDrawDebugCircle, options: options)
    }
    
    @IBAction func dominantButtonPress(sender: NSButton) {
        if sender.identifier! == "leftDomEyeButton" {
            NSUserDefaults.standardUserDefaults().setValue(Eye.left.rawValue, forKey: PeyeConstants.prefDominantEye)
            MidasManager.sharedInstance.setDominantEye(.left)
        } else if sender.identifier! == "rightDomEyeButton" {
            NSUserDefaults.standardUserDefaults().setValue(Eye.right.rawValue, forKey: PeyeConstants.prefDominantEye)
            MidasManager.sharedInstance.setDominantEye(.right)
        } else {
            fatalError("Some unrecognized button was pressed!?")
        }
    }
    
    @IBAction func thicknessSlided(sender: NSSlider) {
        thicknessField.floatValue = sender.floatValue
    }
}

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
    
    @IBOutlet weak var dpiField: NSTextField!
    @IBOutlet weak var thicknessField: NSTextField!
    @IBOutlet weak var thicknessSlider: NSSlider!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
    }
    
    
    @IBAction func thicknessSlided(sender: NSSlider) {
        thicknessField.floatValue = sender.floatValue
    }
}

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
    
    @IBOutlet weak var thicknessField: NSTextField!
    @IBOutlet weak var thicknessSlider: NSSlider!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let formatter = NSNumberFormatter()
        formatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
        formatter.allowsFloats = true
        thicknessField.formatter = formatter
        
        let options = NSDictionary(object: NSNumber(bool: true), forKey: "NSContinuouslyUpdatesValue") as [NSObject : AnyObject]
        
        thicknessSlider.bind("value", toObject: NSUserDefaultsController.sharedUserDefaultsController(), withKeyPath: "values." + PeyeConstants.prefAnnotationLineThickness, options: options)
        thicknessField.bind("value", toObject: NSUserDefaultsController.sharedUserDefaultsController(), withKeyPath: "values." + PeyeConstants.prefAnnotationLineThickness, options: options)
    }
    
    
    @IBAction func thicknessSlided(sender: NSSlider) {
        thicknessField.floatValue = sender.floatValue
    }
}

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

import Foundation
import Cocoa

class GeneralSettingsController: NSViewController {
    
    @IBOutlet weak var leftDomEyeButton: NSButton!
    @IBOutlet weak var rightDomEyeButton: NSButton!
    
    @IBOutlet weak var downloadMetadataCell: NSButtonCell!
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
        let rawEyePreference = UserDefaults.standard.value(forKey: PeyeConstants.prefDominantEye) as! Int
        
        let eyePreference = Eye(rawValue: rawEyePreference)
        
        if eyePreference == .left {
            leftDomEyeButton.state = NSOnState
        } else {
            rightDomEyeButton.state = NSOnState
        }
        
        let floatFormatter = NumberFormatter()
        floatFormatter.numberStyle = NumberFormatter.Style.decimal
        floatFormatter.allowsFloats = true
        thicknessField.formatter = floatFormatter
        
        let intFormatter = NumberFormatter()
        intFormatter.numberStyle = NumberFormatter.Style.decimal
        intFormatter.allowsFloats = false
        dpiField.formatter = intFormatter
        
        let options: [String: AnyObject] = ["NSContinuouslyUpdatesValue": true as AnyObject]
        
        dpiField.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefMonitorDPI, options: options)
        
        thicknessSlider.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefAnnotationLineThickness, options: options)
        thicknessField.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefAnnotationLineThickness, options: options)
        
        
        annotateDefaultOnCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefEnableAnnotate, options: options)
        downloadMetadataCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefDownloadMetadata, options: options)
        midasCheckCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefUseMidas, options: options)
        refinderDrawGazedCheckCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefRefinderDrawGazedUpon, options: options)
        drawDebugCircleCheckCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefDrawDebugCircle, options: options)
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
    
    @IBAction func thicknessSlided(_ sender: NSSlider) {
        thicknessField.floatValue = sender.floatValue
    }
}

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

class AnnotationPreferencesViewController: NSViewController {
    
    @IBOutlet weak var annotateDefaultOnCell: NSButtonCell!
    @IBOutlet weak var thicknessField: NSTextField!
    @IBOutlet weak var thicknessSlider: NSSlider!
    @IBOutlet weak var refinderDrawGazedCheckCell: NSButtonCell!
    @IBOutlet weak var askToSaveAnnotatedPDFCell: NSButtonCell!
    @IBOutlet weak var drawDebugCircleCheckCell: NSButtonCell!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // number formatter for line thickness
        let floatFormatter = NumberFormatter()
        floatFormatter.numberStyle = NumberFormatter.Style.decimal
        floatFormatter.allowsFloats = true
        thicknessField.formatter = floatFormatter
        
        let options: [String: AnyObject] = ["NSContinuouslyUpdatesValue": true as AnyObject]
        
        thicknessSlider.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefAnnotationLineThickness, options: options)
        thicknessField.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefAnnotationLineThickness, options: options)
        annotateDefaultOnCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefEnableAnnotate, options: options)
        refinderDrawGazedCheckCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefRefinderDrawGazedUpon, options: options)
        drawDebugCircleCheckCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefDrawDebugCircle, options: options)
        askToSaveAnnotatedPDFCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefAskToSaveOnClose, options: options)

    }
    @IBAction func thicknessSlided(_ sender: NSSlider) {
        thicknessField.floatValue = sender.floatValue
    }

}

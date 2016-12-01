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

class DebugPreferencesController: NSViewController {

    @IBOutlet weak var drawDebugCircleCheckCell: NSButtonCell!
    @IBOutlet weak var constrainMaxSizeCell: NSButtonCell!
    @IBOutlet weak var refinderDrawGazedCheckCell: NSButtonCell!
    
    @IBOutlet weak var orphanedDeleteProgressBar: NSProgressIndicator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        orphanedDeleteProgressBar.usesThreadedAnimation = true
        
        let options: [String: AnyObject] = ["NSContinuouslyUpdatesValue": true as AnyObject]
        
        refinderDrawGazedCheckCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefRefinderDrawGazedUpon, options: options)
        constrainMaxSizeCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefConstrainWindowMaxSize, options: options)
        drawDebugCircleCheckCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefDrawDebugCircle, options: options)
    }
    
    @IBAction func deleteOrphanedReadingEvents(_ sender: NSButton) {
        sender.isEnabled = false
        
        let bulkProgress = DiMeEraser.deleteAllOrphaned() {
            // re-enable button and unbind progress on done
            DispatchQueue.main.async {
                sender.isEnabled = true
                self.orphanedDeleteProgressBar.unbind("value")
            }
        }
        
        orphanedDeleteProgressBar.bind("value", to: bulkProgress, withKeyPath: "fractionCompleted")
    }
}

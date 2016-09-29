//
//  DebugPreferencesController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 28/09/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Cocoa

class DebugPreferencesController: NSViewController {

    @IBOutlet weak var drawDebugCircleCheckCell: NSButtonCell!
    @IBOutlet weak var refinderDrawGazedCheckCell: NSButtonCell!
    
    @IBOutlet weak var orphanedDeleteProgressBar: NSProgressIndicator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        orphanedDeleteProgressBar.usesThreadedAnimation = true
        
        let options: [String: AnyObject] = ["NSContinuouslyUpdatesValue": true as AnyObject]
        
        refinderDrawGazedCheckCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefRefinderDrawGazedUpon, options: options)
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

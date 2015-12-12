//
//  ThresholdEditor.swift
//  PeyeDF
//
//  Created by Marco Filetti on 13/12/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa

class ThresholdEditor: NSViewController {
    
    @IBOutlet weak var readSlider: NSSlider!
    @IBOutlet weak var interestingSlider: NSSlider!
    @IBOutlet weak var criticalSlider: NSSlider!
    
    weak var detailDelegate: HistoryDetailDelegate?
    
    @IBAction func applyPress(sender: NSButton) {
        detailDelegate?.setEyeThresholds(readSlider.doubleValue, interestingThresh: interestingSlider.doubleValue, criticalThresh: criticalSlider.doubleValue)
    }
    
}
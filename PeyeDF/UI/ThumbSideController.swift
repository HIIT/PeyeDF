//
//  ThumbSideController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 24/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Cocoa
import Quartz

/// Controller for the Thumbnail side Document split view
class ThumbSideController: NSViewController {
    
    @IBOutlet weak var myThumb: PDFThumbnailView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func awakeFromNib() {
        //constr.constant = CGFloat(0)
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }

}



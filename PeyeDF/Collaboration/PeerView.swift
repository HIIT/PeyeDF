//
//  PeerView.swift
//  PeyeDF
//
//  Created by Marco Filetti on 27/05/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Cocoa

class PeerView: NSView {
    
    @IBOutlet weak var peerImg: NSImageView!
    @IBOutlet weak var peerLab: NSTextField!
    @IBOutlet weak var filenameLab: NSTextField!
    @IBOutlet weak var titleLab: NSTextField!
    @IBOutlet weak var readButton: NSButton!
    @IBOutlet weak var progBar: NSProgressIndicator!
    

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        // Drawing code here.
    }
    
    func setTitle(newtitle: String) {
        titleLab.stringValue = newtitle
    }
}

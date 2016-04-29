//
//  TagRemoveButton.swift
//  TagStack
//
//  Created by Marco Filetti on 05/04/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Cocoa

class TagViewButton: NSButton {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        let trackingArea = NSTrackingArea(rect: self.bounds, options: [NSTrackingAreaOptions.MouseEnteredAndExited, NSTrackingAreaOptions.ActiveAlways], owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }

    override func mouseExited(theEvent: NSEvent) {
        for obj in self.superview!.subviews {
            if let txt = obj as? NSTextField {
                txt.font = NSFont.systemFontOfSize(txt.font!.pointSize)
            }
        }
    }
    
    override func mouseEntered(theEvent: NSEvent) {
        for obj in self.superview!.subviews {
            if let txt = obj as? NSTextField {
                txt.font = NSFont.boldSystemFontOfSize(txt.font!.pointSize)
            }
        }
    }
    
}

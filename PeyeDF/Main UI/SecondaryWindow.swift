//
//  SecondaryWindow.swift
//  PeyeDF
//
//  Created by Marco Filetti on 31/05/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation
import Cocoa

class SecondaryWindow: NSWindow {
    override var canBecomeMainWindow: Bool { get {
        return false
    } }
    
    override var canBecomeKeyWindow: Bool { get {
        return false
    } }
}
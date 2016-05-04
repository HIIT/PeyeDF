//
//  MyDelegate.swift
//  TagStack
//
//  Created by Marco Filetti on 05/04/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation
import Cocoa

/// Class used to auto complete recently inputted tags
class TagFieldDelegate: NSObject, NSTextFieldDelegate {
    
    func control(control: NSControl, textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String] {
        index.memory = -1
        let recentTags = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.defaultsSavedTags) as! [String]
        return recentTags.sort().filter({$0.hasPrefix(textView.string ?? "")})
    }
    
}
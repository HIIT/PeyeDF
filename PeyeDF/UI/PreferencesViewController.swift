//
//  PreferencesWindowController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 25/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa

class PreferencesViewController: NSViewController {
    
    @IBOutlet weak var urlField: NSTextField!
    @IBOutlet weak var usernameField: NSTextField!
    @IBOutlet weak var passwordField: NSTextField!
    @IBOutlet weak var documentEventSwitchCell: NSButtonCell!
    
    /// Create view and programmatically set-up bindings
    override func viewDidLoad() {
        super.viewDidLoad()
        let options = NSDictionary(object: NSNumber(bool: true), forKey: "NSContinuouslyUpdatesValue") as [NSObject : AnyObject]
        
        urlField.bind("value", toObject: NSUserDefaultsController.sharedUserDefaultsController(), withKeyPath: "values." + PeyeConstants.prefServerURL, options: options)
        
        usernameField.bind("value", toObject: NSUserDefaultsController.sharedUserDefaultsController(), withKeyPath: "values." + PeyeConstants.prefServerUserName, options: options)
        
        passwordField.bind("value", toObject: NSUserDefaultsController.sharedUserDefaultsController(), withKeyPath: "values." + PeyeConstants.prefServerPassword, options: options)
        
        // the following will set
        // (PeyeConstants.prefSendEventOnFocusSwitch)
        // to optional int 0 when off and nonzero (1) when on
        documentEventSwitchCell.bind("value", toObject: NSUserDefaultsController.sharedUserDefaultsController(), withKeyPath: "values." + PeyeConstants.prefSendEventOnFocusSwitch, options: options)
        
    }
}
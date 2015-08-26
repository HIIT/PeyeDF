//
//  HistoryManager.swift
//  PeyeDF
//
//  Created by Marco Filetti on 26/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

// The history manager is a singleton and keeps track of all history events happening trhough the application.
// This includes, for example, timers which trigger at predefined intervals (such as closing events after a
// specific amount of time has passed, assuming that the user went away from keyboard).

import Foundation

class HistoryManager {
    
    /// Returns a shared instance of this class. This is the designed way of accessing the history manager.
    static let sharedManager = HistoryManager()
    
    private init() {
        
    }
}
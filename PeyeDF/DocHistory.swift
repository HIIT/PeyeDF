//
//  DocHistory.swift
//  PeyeDF
//
//  Created by Marco Filetti on 02/07/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//
// Tracking and saving document history (relative to all documents; this is hence similar to AppSingleton)
// We save all data corresponding to an instance of a document read for > 1 second
// Data stored (for each entry):
//
// - Document name
// - Whether 1 one multiple pages are being seen (bool, multipage)
// - Page number (if multiple pages are seen, first page being seen)
// - Pages list (array of page numbers being seen, if >1)
// - Visible proportion of page (if <1 page being seen) OR
// - Visible proportion of document (if >1 page being seen)
// - Start time
// - End time (must be >1s from start time)
// - Duration
//


// implementation:
// any "entry" event (key window made, scrolling done) starts a timer
// there can only be one timer
// timer starts with minimum duration, after this passes a copy of the current status is made
// any exit event closes the status (inputting end time and duration)
// exit events are screen saver starts, window lost, scrolling done (note scrolling is both an entry and exit event)
// need to know user's screen saver delay
// timer: http://stackoverflow.com/questions/24369602/using-an-nstimer-in-swift

// start event method
// if there's a timer running (validated property) and create new one
// if timer is already invalidated, still create a new one
// created timer will save current status in new object and set saveStatus boolean to true
// use saveStatus bool when a new timer gets created to check if we need to save status and put in duration, etc
// use NSWindowDidChangeOcclusionStateNotification as an enter/exit event

import Foundation

class DocHistory {
    static let getHistory = AllHistory()
}

class AllHistory: NSObject {
    
}
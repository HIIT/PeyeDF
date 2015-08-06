//
//  DocHistory.swift
//  PeyeDF
//
//  Created by Marco Filetti on 02/07/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//
// Tracking and saving document history (relative to one documents; every document has its own history)
// We save all data corresponding to an instance of a document read for > 10 seconds
// refer to https://github.com/HIIT/PeyeDF/wiki/Data-Format

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

// remember to start logging if sending window is still key window

// when calculating proportion of pages, remember there are 10 HDPI pixels (5 points) separating pages at size 100%
import Foundation

class DocHistory {
    static let getHistory = AllHistory()
}

class AllHistory: NSObject {
    
}
//
//  DocHistory.swift
//  PeyeDF
//
//  Created by Marco Filetti on 02/07/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//
// Tracking and saving document history (relative to one document; every document has its own history).
// This class bridges PeyeDF's own ReadingEvent struct with a Dictionary suitable for JSON serialization.
// Represent a ReadingEvent in DiMe. Refer to https://github.com/HIIT/PeyeDF/wiki/Data-Format for the data which is passed to DiMe

// implementation:
// We save all data corresponding to an instance of a document read for > 10 seconds
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
import Cocoa

struct ReadingEvent {
    var multiPage: Bool // yes if > 1 page is currently being displayed
    var visiblePages: [Int]  // vector of pages specifying the pages currently being displayed, starting from 0 (length should be > 1 if multiPage == true)
    var pageRects: [NSRect]  // A list of rectangles representing where the viewport is placed for each page. All the rects should fit within the page. Rect dimensions refer to points in a 72 dpi space where the bottom left is the origin, as in Apple's PDFKit. A page in US Letter format (often used for papers) translates to approx 594 x 792 points.
    
}

extension NSRect {
    func toDict() -> [String: Int] {
        return [String: Int]()
    }
}
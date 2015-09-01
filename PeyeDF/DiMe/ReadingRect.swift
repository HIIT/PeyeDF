//
//  ReadingRect.swift
//  PeyeDF
//
//  Created by Marco Filetti on 01/09/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

/// Represents a rect for DiMe usage ("replaces" NSRect in "external" communications)
public struct ReadingRect: Equatable, Dictionariable {
    var origin: NSPoint
    var size: NSSize
    var readingClass: Int = 0
    
    init() {
        origin = NSPoint(x: 0, y: 0)
        size = NSSize(width: 0, height: 0)
    }
    
    init(origin: NSPoint, size: NSSize) {
        self.origin = origin
        self.size = size
    }
    
    init(rect: NSRect) {
        self.origin = rect.origin
        self.size = rect.size
    }
    
    mutating func setClass(newClass: Int) {
        self.readingClass = newClass
    }
    
    /// Returns itself in a dict of strings, matching DiMe's Rect class
    func getDict() -> [String : AnyObject] {
        var retDict = [String: AnyObject]()
        retDict["origin"] = self.origin.getDict()
        retDict["size"] = self.size.getDict()
        retDict["readingClass"] = self.readingClass
        return retDict
    }
}

public func == (lhs: ReadingRect, rhs: ReadingRect) -> Bool {
    return lhs.origin.x == rhs.origin.x &&
           lhs.origin.y == rhs.origin.y &&
           lhs.size.width == rhs.size.width &&
           lhs.size.height == rhs.size.height &&
           lhs.readingClass == rhs.readingClass
}
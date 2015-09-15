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
    var readingClass: ReadingClass = ReadingClass.Unset
    var classSource: ClassSource = ClassSource.Unset
    
    init() {
        origin = NSPoint(x: 0, y: 0)
        size = NSSize(width: 0, height: 0)
    }
    
    init(origin: NSPoint, size: NSSize, readingClass: ReadingClass , classSource: ClassSource) {
        self.origin = origin
        self.size = size
        self.readingClass = readingClass
        self.classSource = classSource
    }
    
    init(rect: NSRect, readingClass: ReadingClass, classSource: ClassSource) {
        self.origin = rect.origin
        self.size = rect.size
        self.readingClass = readingClass
        self.classSource = classSource
    }
    
    init(rect: NSRect) {
        self.origin = rect.origin
        self.size = rect.size
    }
    
    mutating func setClass(newClass: ReadingClass) {
        self.readingClass = newClass
    }
    mutating func setClassSource(newClassSource: ClassSource) {
        self.classSource = newClassSource
    }
    
    /// Returns itself in a dict of strings, matching DiMe's Rect class
    func getDict() -> [String : AnyObject] {
        var retDict = [String: AnyObject]()
        retDict["origin"] = self.origin.getDict()
        retDict["size"] = self.size.getDict()
        retDict["readingClass"] = self.readingClass.rawValue
        retDict["classSource"] = self.classSource.rawValue
        return retDict
    }
}

public func == (lhs: ReadingRect, rhs: ReadingRect) -> Bool {
    return lhs.origin.x == rhs.origin.x &&
           lhs.origin.y == rhs.origin.y &&
           lhs.size.width == rhs.size.width &&
           lhs.size.height == rhs.size.height &&
           lhs.readingClass == rhs.readingClass &&
           lhs.classSource == rhs.classSource
}
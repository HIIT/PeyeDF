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
    var pageIndex: NSNumber
    var rect: NSRect
    var readingClass: ReadingClass = ReadingClass.Unset
    var classSource: ClassSource = ClassSource.Unset
    
    init(pageIndex: Int, origin: NSPoint, size: NSSize, readingClass: ReadingClass , classSource: ClassSource) {
        self.pageIndex = pageIndex
        self.rect = NSRect(origin: origin, size: size)
        self.readingClass = readingClass
        self.classSource = classSource
    }
    
    init(pageIndex: Int, rect: NSRect, readingClass: ReadingClass, classSource: ClassSource) {
        self.pageIndex = pageIndex
        self.rect = rect
        self.readingClass = readingClass
        self.classSource = classSource
    }
    
    init(pageIndex: Int, rect: NSRect) {
        self.pageIndex = pageIndex
        self.rect = rect
    }
    
    /// Creates a rect from a (dime-used) json object
    init(fromJson json: JSON) {
        let origin = NSPoint(x: json["origin"]["x"].doubleValue, y: json["origin"]["y"].doubleValue)
        let size = NSSize(width: json["size"]["width"].doubleValue, height: json["size"]["height"].doubleValue)
        self.rect = NSRect(origin: origin, size: size)
        self.readingClass = ReadingClass(rawValue: json["readingClass"].intValue)!
        self.classSource = ClassSource(rawValue: json["classSource"].intValue)!
        self.pageIndex = json["pageIndex"].intValue
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
        retDict["pageIndex"] = self.pageIndex
        retDict["origin"] = self.rect.origin.getDict()
        retDict["size"] = self.rect.size.getDict()
        retDict["readingClass"] = self.readingClass.rawValue
        retDict["classSource"] = self.classSource.rawValue
        return retDict
    }
}

public func == (lhs: ReadingRect, rhs: ReadingRect) -> Bool {
    return lhs.pageIndex == rhs.pageIndex &&
           lhs.rect == rhs.rect &&
           lhs.readingClass == rhs.readingClass &&
           lhs.classSource == rhs.classSource
}
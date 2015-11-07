//
//  DiMeData.swift
//  PeyeDF
//
//  Created by Marco Filetti on 24/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

/// This class is made for subclassing. It represents data common to all dime objects (see /dime-server/src/main/java/fi/hiit/dime/data/DiMeData.java in the dime project).
class DiMeBase: NSObject, Dictionariable {
    
    /// Main dictionary storing all data
    ///
    /// **Important**: all sublasses must set these two keys, in order to be decoded by dime:
    /// - @type
    /// - type
    var theDictionary = [String: AnyObject]()
    
    override init() {
        super.init()
    }
    
    /// Simply returns the dictionary. Can be overridden by subclasses that want
    /// to edit the dictionary before sending it.
    func getDict() -> [String : AnyObject] {
        return theDictionary
    }
}

/// Represents a simple range with a start and end value
struct DiMeRange: Dictionariable, Equatable {
    var min: NSNumber
    var max: NSNumber
    
    /// Returns min and max in a dict
    func getDict() -> [String : AnyObject] {
        var retDict = [String: AnyObject]()
        retDict["min"] = min
        retDict["max"] = max
        return retDict
    }
}

func == (lhs: DiMeRange, rhs: DiMeRange) -> Bool {
    return lhs.max == rhs.max &&
        lhs.min == rhs.min
}


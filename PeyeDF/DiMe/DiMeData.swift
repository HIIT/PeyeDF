//
//  DiMeData.swift
//  PeyeDF
//
//  Created by Marco Filetti on 24/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

/// Doesn't seem to contain anything that needs to be stored, yet
class DiMeData {
    
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


//
//  Fixation.swift
//  PeyeDF
//
//  Created by Marco Filetti on 05/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

/// Events in SMI terminology include fixations

import Foundation

struct SMIFixationEvent {
    var eye: Eye
    var startTime: Int
    var endTime: Int
    var duration: Int
    var positionX: Double
    var positionY: Double
}

/// Returns an array of fixations that happened after the given startTime (startTime + 1), for the given eye, using the given json
///
/// - returns: nil if nothing is new since last time, or an array of events containing all new events for the given eye
func getAllFixationsAfter(previousTime: Int, forEye eye: Eye, fromJSON json: JSON) -> [SMIFixationEvent]? {
    // find index to start from
    let timeArray = json[0]["return"]["startTime"]["data"].arrayObject as! [Int]
    
    var i = binaryGreaterOrEqOnSortedArray(timeArray, target: previousTime + 1)
    
    // The end was returned, it means nothing is new
    if i >= timeArray.count {
        return nil
    }
    
    let allEyes = json[0]["return"]["eye"]["data"].arrayObject as! [Int]
    let allStartTimes = json[0]["return"]["startTime"]["data"].arrayObject as! [Int]
    let allEndTimes = json[0]["return"]["endTime"]["data"].arrayObject as! [Int]
    let allDurations = json[0]["return"]["duration"]["data"].arrayObject as! [Int]
    let allXs = json[0]["return"]["positionX"]["data"].arrayObject as! [Double]
    let allYs = json[0]["return"]["positionY"]["data"].arrayObject as! [Double]
    
    var retVal = [SMIFixationEvent]()
    
    // TODO: remove this debugging check
    if !(allEyes.count == allStartTimes.count && allStartTimes.count == allEndTimes.count && allEndTimes.count == allYs.count) {
        fatalError("Counts do not match!")
    }
    
    // loop all remaining items and add if they match eye and have duration
    while i < timeArray.count {
        if allEyes[i] == eye.rawValue {
            if allDurations[i] > 0 {
                retVal.append(SMIFixationEvent(eye: eye, startTime: allStartTimes[i], endTime: allEndTimes[i], duration: allDurations[i], positionX: allXs[i], positionY: allYs[i]))
            }
        }
        
        i++
    }
    
    if retVal.count > 0 {
        return retVal
    } else {
        return nil
    }
}
//
// Copyright (c) 2015 Aalto University
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

/// Events in SMI terminology include fixations

import Foundation

struct SMIFixationEvent: Equatable {
    var eye: Eye
    var startTime: Int
    var endTime: Int
    var duration: Int
    var positionX: Double
    var positionY: Double
    var unixtime: Int
}

func == (lhs: SMIFixationEvent, rhs: SMIFixationEvent) -> Bool {
    return lhs.eye == rhs.eye &&
           lhs.startTime == rhs.startTime &&
           lhs.endTime == rhs.endTime &&
           lhs.duration == rhs.duration &&
           lhs.positionX == rhs.positionX &&
           lhs.positionY == rhs.positionY &&
           lhs.unixtime == rhs.unixtime
}

/// Returns an array of fixations for the given eye **which have duration > 0**, using the given json
///
/// - returns: an array of fixation events and if some value was found and the last valid unix time
///            of the last fixation found (nil if no new values were found)
func getTimedFixationsAfter(unixtime minUnixtime: Int, forEye eye: Eye, fromJSON json: JSON) -> (array: [SMIFixationEvent], lastUnixtime: Int)? {
    // find index to start from
    let timeArray = json[0]["return"]["startTime"]["data"].arrayObject as! [Int]
    
    if timeArray.count == 0 {
        return nil
    }
    
    let allEyes = json[0]["return"]["eye"]["data"].arrayObject as! [Int]
    let allStartTimes = json[0]["return"]["startTime"]["data"].arrayObject as! [Int]
    let allEndTimes = json[0]["return"]["endTime"]["data"].arrayObject as! [Int]
    let allDurations = json[0]["return"]["duration"]["data"].arrayObject as! [Int]
    let allXs = json[0]["return"]["positionX"]["data"].arrayObject as! [Double]
    let allYs = json[0]["return"]["positionY"]["data"].arrayObject as! [Double]
    let allMarcotimes = json[0]["return"]["marcotime"]["data"].arrayObject as! [Int]
    
    var retVal = [SMIFixationEvent]()
    
    var i = 0
    var lastUnixtime: Int?
    // loop all remaining items and add if they match eye and have duration
    while i < timeArray.count {
        if allEyes[i] == eye.rawValue {
            if allDurations[i] > 0 {
                /// marco time was unix time minus a constant
                let unixtime = allMarcotimes[i] + 1446909066675
                if unixtime > minUnixtime {
                    retVal.append(SMIFixationEvent(eye: eye, startTime: allStartTimes[i], endTime: allEndTimes[i], duration: allDurations[i], positionX: allXs[i], positionY: allYs[i], unixtime: unixtime))
                }
                if lastUnixtime == nil || unixtime > lastUnixtime! {
                    lastUnixtime = unixtime
                }
            }
        }
        
        i += 1
    }
    
    if retVal.count > 0 {
        return (array: retVal, lastUnixtime: lastUnixtime!)
    } else {
        return nil
    }
}
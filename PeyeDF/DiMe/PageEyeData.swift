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

import Foundation

struct PageEyeDataChunk: Dictionariable {
    var Xs: [NSNumber]
    var Ys: [NSNumber]
    /// pupil sizes
    var Ps: [NSNumber]?
    var startTimes: [NSNumber]
    var endTimes: [NSNumber]
    var durations: [NSNumber]
    var pageIndex: Int?
    let scaleFactor: NSNumber
    let unixt: Int
    
    /// unixtimes are not sent to dime, but are used to filter fixations
    /// so that those recorded around a specific time are not sent to dime
    var unixtimes: [Int]
    

    init(Xs: [NSNumber], Ys: [NSNumber], startTimes: [NSNumber], endTimes: [NSNumber], durations: [NSNumber], unixtimes: [Int], pageIndex: Int, scaleFactor: NSNumber) {
        self.Xs = Xs
        self.Ys = Ys
        self.startTimes = startTimes
        self.endTimes = endTimes
        self.durations = durations
        self.pageIndex = pageIndex
        self.unixtimes = unixtimes
        self.scaleFactor = scaleFactor
        self.unixt = NSDate().unixTime
    }
    
    init(Xs: [NSNumber], Ys: [NSNumber], Ps: [NSNumber], startTimes: [NSNumber], endTimes: [NSNumber], durations: [NSNumber], unixtimes: [Int], pageIndex: Int, scaleFactor: NSNumber) {
        self.Xs = Xs
        self.Ys = Ys
        self.Ps = Ps
        self.startTimes = startTimes
        self.endTimes = endTimes
        self.durations = durations
        self.pageIndex = pageIndex
        self.unixtimes = unixtimes
        self.scaleFactor = scaleFactor
        self.unixt = NSDate().unixTime
    }
    
    /// Creates data supplied from a json in dime format
    init(fromDime json: JSON) {
        self.Xs = json["Xs"].arrayObject! as! [NSNumber]
        self.Ys = json["Ys"].arrayObject! as! [NSNumber]
        if let Ps = json["Ps"].arrayObject as? [NSNumber] {
            self.Ps = Ps
        }
        self.startTimes = json["startTimes"].arrayObject! as! [NSNumber]
        self.endTimes = json["endTimes"].arrayObject! as! [NSNumber]
        self.durations = json["durations"].arrayObject! as! [NSNumber]
        self.pageIndex = json["pageIndex"].intValue
        self.scaleFactor = json["scaleFactor"].doubleValue
        self.unixt = json["unixt"].intValue
        self.unixtimes = [Int]()
    }
    
    mutating func appendEvent(x: NSNumber, y: NSNumber, startTime: NSNumber, endTime: NSNumber, duration: NSNumber, unixtime: Int) {
        self.Xs.append(x)
        self.Ys.append(y)
        self.startTimes.append(startTime)
        self.endTimes.append(endTime)
        self.durations.append(duration)
        self.unixtimes.append(unixtime)
    }
    
    mutating func appendEvent(x: NSNumber, y: NSNumber, p: NSNumber, startTime: NSNumber, endTime: NSNumber, duration: NSNumber, unixtime: Int) {
        self.Xs.append(x)
        self.Ys.append(y)
        self.Ps!.append(p)
        self.startTimes.append(startTime)
        self.endTimes.append(endTime)
        self.durations.append(duration)
        self.unixtimes.append(unixtime)
    }
    
    mutating func appendData(Xs: [NSNumber], Ys: [NSNumber], startTimes: [NSNumber], endTimes: [NSNumber], durations: [NSNumber], unixtimes: [Int]) {
        self.Xs.appendContentsOf(Xs)
        self.Ys.appendContentsOf(Ys)
        self.startTimes.appendContentsOf(startTimes)
        self.endTimes.appendContentsOf(endTimes)
        self.durations.appendContentsOf(durations)
        self.unixtimes.appendContentsOf(unixtimes)
    }
    
    mutating func appendData(Xs: [NSNumber], Ys: [NSNumber], Ps: [NSNumber], startTimes: [NSNumber], endTimes: [NSNumber], durations: [NSNumber], unixtimes: [Int]) {
        self.Xs.appendContentsOf(Xs)
        self.Ys.appendContentsOf(Ys)
        self.Ps!.appendContentsOf(Ps)
        self.startTimes.appendContentsOf(startTimes)
        self.endTimes.appendContentsOf(endTimes)
        self.durations.appendContentsOf(durations)
        self.unixtimes.appendContentsOf(unixtimes)
    }
    
    /// Check if xs, ys and timepoints are all the same length, traps if not.
    func autoCheck() {
        if let Ps = self.Ps {
            if !(Xs.count == Ys.count && Ys.count == startTimes.count && startTimes.count == Ps.count) {
                let exception = NSException(name: "Incorrect count", reason: nil, userInfo: nil)
                exception.raise()
            }
        } else {
            if !(Xs.count == Ys.count && Ys.count == startTimes.count) {
                let exception = NSException(name: "Incorrect count", reason: nil, userInfo: nil)
                exception.raise()
            }
        }
    }
    
    /// the passed unixtimes will cause eye data with a unixtime within a range of
    /// excludeEyeUnixTimeMs of the given paramter to be removed from the current eye data
    mutating func filterData(excludeUnixtimes: [Int]) {
        for i in 0 ..< excludeUnixtimes.count {
            var j = 0
            while j < unixtimes.count {
                if unixtimes[j] > excludeUnixtimes[i] - PeyeConstants.excludeEyeUnixTimeMs &&
                    unixtimes[j] < excludeUnixtimes[i] + PeyeConstants.excludeEyeUnixTimeMs {
                        
                    unixtimes.removeAtIndex(j)
                    Xs.removeAtIndex(j)
                    Ys.removeAtIndex(j)
                    if let _ = Ps {
                        Ps!.removeAtIndex(j)
                    }
                    startTimes.removeAtIndex(j)
                    endTimes.removeAtIndex(j)
                    durations.removeAtIndex(j)
                        
                } else {
                    j += 1
                }
            }
        }
    }
    
    func getDict() -> [String : AnyObject] {
        
        // save numbers here to remove invalid ones
        var arraysToCheck = [Xs, Ys, startTimes, endTimes, durations]
        if let _ = self.Ps {
            arraysToCheck.append(self.Ps!)
        }
        
        // remove invalid nsnumbers from array (if any)
        var i = 0
        while i < startTimes.count {
            var foundInvalid = false
            for a in 0 ..< arraysToCheck.count {
                if !arraysToCheck[a][i].isValid() {
                    for aa in 0 ..< arraysToCheck.count {
                        arraysToCheck[aa].removeAtIndex(i)
                    }
                    foundInvalid = true
                    AppSingleton.log.error("Found invalid NSNumber")
                    break
                }
            }
            if !foundInvalid {
                i += 1
            }
        }
        
        var retDict = [String: AnyObject]()
        
        if let _ = self.Ps {
            retDict["Ps"] = arraysToCheck[5]
        }
        
        retDict["Xs"] = arraysToCheck[0]
        retDict["Ys"] = arraysToCheck[1]
        retDict["startTimes"] = arraysToCheck[2]
        retDict["endTimes"] = arraysToCheck[3]
        retDict["durations"] = arraysToCheck[4]
        retDict["unixt"] = self.unixt
        retDict["scaleFactor"] = self.scaleFactor
        if let pi = pageIndex {
            if pi >= 0 && pi <= PeyeConstants.maxAcceptablePageIndex {
                retDict["pageIndex"] = pi
            } else {
                retDict["pageIndex"] = -1
                AppSingleton.log.error("Found out of range page index")
            }
        } else {
            retDict["pageIndex"] = -1
            AppSingleton.log.error("Found nil page index")
        }
        
        return retDict
        
    }
}

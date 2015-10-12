//
//  PageEyeData.swift
//  PeyeDF
//
//  Created by Marco Filetti on 15/09/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

struct PageEyeData: Dictionariable {
    var Xs: [NSNumber]
    var Ys: [NSNumber]
    /// pupil sizes
    var Ps: [NSNumber]?
    var startTimes: [NSNumber]
    var endTimes: [NSNumber]
    var durations: [NSNumber]
    var pageIndex: Int?
    
    init(Xs: [NSNumber], Ys: [NSNumber], startTimes: [NSNumber], endTimes: [NSNumber], durations: [NSNumber], pageIndex: Int) {
        self.Xs = Xs
        self.Ys = Ys
        self.startTimes = startTimes
        self.endTimes = endTimes
        self.durations = durations
        self.pageIndex = pageIndex
    }
    
    init(Xs: [NSNumber], Ys: [NSNumber], Ps: [NSNumber], startTimes: [NSNumber], endTimes: [NSNumber], durations: [NSNumber], pageIndex: Int) {
        self.Xs = Xs
        self.Ys = Ys
        self.Ps = Ps
        self.startTimes = startTimes
        self.endTimes = endTimes
        self.durations = durations
        self.pageIndex = pageIndex
    }
    
    mutating func appendEvent(x: NSNumber, y: NSNumber, startTime: NSNumber, endTime: NSNumber, duration: NSNumber) {
        self.Xs.append(x)
        self.Ys.append(y)
        self.startTimes.append(startTime)
        self.endTimes.append(endTime)
        self.durations.append(duration)
    }
    
    mutating func appendEvent(x: NSNumber, y: NSNumber, p: NSNumber, startTime: NSNumber, endTime: NSNumber, duration: NSNumber) {
        self.Xs.append(x)
        self.Ys.append(y)
        self.Ps!.append(p)
        self.startTimes.append(startTime)
        self.endTimes.append(endTime)
        self.durations.append(duration)
    }
    
    mutating func appendData(Xs: [NSNumber], Ys: [NSNumber], startTimes: [NSNumber], endTimes: [NSNumber], durations: [NSNumber]) {
        self.Xs.appendContentsOf(Xs)
        self.Ys.appendContentsOf(Ys)
        self.startTimes.appendContentsOf(startTimes)
        self.endTimes.appendContentsOf(endTimes)
        self.durations.appendContentsOf(durations)
    }
    
    mutating func appendData(Xs: [NSNumber], Ys: [NSNumber], Ps: [NSNumber], startTimes: [NSNumber], endTimes: [NSNumber], durations: [NSNumber]) {
        self.Xs.appendContentsOf(Xs)
        self.Ys.appendContentsOf(Ys)
        self.Ps!.appendContentsOf(Ps)
        self.startTimes.appendContentsOf(startTimes)
        self.endTimes.appendContentsOf(endTimes)
        self.durations.appendContentsOf(durations)
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
    
    func getDict() -> [String : AnyObject] {
        
        var retDict = [String: AnyObject]()
        
        if let Ps = self.Ps {
            retDict["Ps"] = Ps
        }
        
        retDict["Xs"] = Xs
        retDict["Ys"] = Ys
        retDict["startTimes"] = startTimes
        retDict["endTimes"] = endTimes
        retDict["durations"] = durations
        retDict["pageIndex"] = pageIndex!
        
        return retDict
        
    }
}

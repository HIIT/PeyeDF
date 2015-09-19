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
    var Ps: [NSNumber]?
    var timepoints: [NSNumber]
    var pageIndex: Int?
    
    init(Xs: [NSNumber], Ys: [NSNumber], timepoints: [NSNumber], pageIndex: Int) {
        self.Xs = Xs
        self.Ys = Ys
        self.timepoints = timepoints
        self.pageIndex = pageIndex
    }
    
    init(Xs: [NSNumber], Ys: [NSNumber], Ps: [NSNumber], timepoints: [NSNumber], pageIndex: Int) {
        self.Xs = Xs
        self.Ys = Ys
        self.Ps = Ps
        self.timepoints = timepoints
        self.pageIndex = pageIndex
    }
    
    mutating func appendData(Xs: [NSNumber], Ys: [NSNumber], timepoints: [NSNumber]) {
        self.Xs.appendContentsOf(Xs)
        self.Ys.appendContentsOf(Ys)
        self.timepoints.appendContentsOf(timepoints)
    }
    
    mutating func appendData(Xs: [NSNumber], Ys: [NSNumber], Ps: [NSNumber], timepoints: [NSNumber]) {
        self.Xs.appendContentsOf(Xs)
        self.Ys.appendContentsOf(Ys)
        self.Ps!.appendContentsOf(Ps)
        self.timepoints.appendContentsOf(timepoints)
    }
    
    /// Check if xs, ys and timepoints are all the same length, traps if not.
    func autoCheck() {
        if let Ps = self.Ps {
            if !(Xs.count == Ys.count && Ys.count == timepoints.count && timepoints.count == Ps.count) {
                let exception = NSException(name: "Incorrect count", reason: nil, userInfo: nil)
                exception.raise()
            }
        } else {
            if !(Xs.count == Ys.count && Ys.count == timepoints.count) {
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
        retDict["timepoints"] = timepoints
        retDict["pageIndex"] = pageIndex!
        
        return retDict
        
    }
}

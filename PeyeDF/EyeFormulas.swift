//
//  EyeFormulas.swift
//  PeyeDF
//
//  Created by Marco Filetti on 11/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

let pointsForVSeg: CGFloat = 10  // how many points are needed before inserting an additional selection point

// TODO: current implementation temporary
/// Given a zoom level, return how many points should that zoom level span
/// current idea: we select 7 lines at zoom 1, 5 lines at zoom 2 and 3 lines at zoom 3
/// corresponding (in one doc) to 7cm, 4cm, 2cm (2.76, 1.57, 0.79)
/// corresponding to (at 72dpi) 198, 113, 57 points
/// formula (29*x^2-257*x+624)/2}
/// divide everything by 3 instead of two
func zoomToPoints(zoomLevel: CGFloat) -> CGFloat {
    let a = 29*(pow(zoomLevel, 2))
    let b = 257*zoomLevel
    return CGFloat(round((a-b+624)/3))
}

/// Given a selection and a zoom level, return an array of points spanning through
/// the wanted vertical space
func multiVPoint(point: NSPoint, zoomLevel: CGFloat) -> [NSPoint] {
    var pointSpan = zoomToPoints(zoomLevel)
    let nOfPoints = Int(floor(pointSpan/pointsForVSeg))
    var pointArray = Array<NSPoint>(count: nOfPoints, repeatedValue: point)
    
    pointSpan = CGFloat(nOfPoints) * pointsForVSeg
    
    let startY = point.y + pointSpan / 2
    let endY = point.y - pointSpan / 2
    // (remember origin is at bottom left)
    var i = 0
    for var newY = startY ; newY > endY; newY -= pointsForVSeg {
        pointArray[i].y = newY
        ++i
    }
    assert(i>=count(pointArray), "Index is less than array length")
    return pointArray
}
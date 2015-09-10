//
//  EyeFormulas.swift
//  PeyeDF
//
//  Created by Marco Filetti on 11/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

/// Given a point and a zoom level (PDFView's scaleFactor), return an array of points, separated by two points each (defaultStep),
/// that covers the defaultInchSpan vertically. The page rectangle (i.e. media box) is passed
/// in to avoid adding points which are not within 28 points (defaultMargin) (approximately 1cm in page space) to the returned array
func verticalFocalPoints(fromPoint point: NSPoint, zoomLevel: CGFloat, pageRect: NSRect) -> [NSPoint] {
    let defaultMargin: CGFloat = 28
    let defaultStep: CGFloat = 2
    
    let pointSpan = defaultInchSpan() * AppSingleton.getMonitorDPI() / zoomLevel
    let fitInRect = NSInsetRect(pageRect, defaultMargin, defaultMargin)
    
    var pointArray = [NSPoint]()
    
    let startPoint = NSPoint(x: point.x, y: point.y + pointSpan / 2)
    let endPoint = NSPoint(x: point.x, y: point.y - pointSpan / 2)
    var currentPoint = startPoint
    while currentPoint.y >= endPoint.y {
        if NSPointInRect(currentPoint, fitInRect) {
            pointArray.append(currentPoint)
        }
        
        currentPoint.y -= defaultStep
    }
    
    return pointArray
}


/// Returns how many inches should be covered by the participant's fovea at a predefined distance
func defaultInchSpan() -> CGFloat {
    let defaultDistance: CGFloat = 24  // assuming to be approx. 60cm away from screen
    let defaultAngle: CGFloat = degToRad(3)  // fovea's covered angle
    return 2 * defaultDistance * tan(defaultAngle/2)
}

/// Converts degrees to radians (xcode tan function is in radians)
func degToRad(deg: CGFloat) -> CGFloat {
    return deg * CGFloat(M_PI) / 180.0
}
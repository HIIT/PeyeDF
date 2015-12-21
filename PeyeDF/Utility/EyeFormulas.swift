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
    
    let fitInRect = NSInsetRect(pageRect, defaultMargin, defaultMargin)
    
    var pointArray = [NSPoint]()
    let points = pointSpan(zoomLevel: zoomLevel, dpi: AppSingleton.getComputedDPI()!, distancemm: MidasManager.sharedInstance.lastValidDistance)
    
    let startPoint = NSPoint(x: point.x, y: point.y + points / 2)
    let endPoint = NSPoint(x: point.x, y: point.y - points / 2)
    var currentPoint = startPoint
    while currentPoint.y >= endPoint.y {
        if NSPointInRect(currentPoint, fitInRect) {
            pointArray.append(currentPoint)
        }
        
        currentPoint.y -= defaultStep
    }
    
    return pointArray
}

/// Returns how many points should be covered by the participant's fovea at the current distance, given a zoom level (scale factor) and monitor DPI
func pointSpan(zoomLevel zoomLevel: CGFloat, dpi: Int, distancemm: CGFloat) -> CGFloat {
    return inchSpan(distancemm) * CGFloat(dpi) / zoomLevel
}

/// Returns how many inches should be covered by the participant's fovea at the given distance in
/// millimetres
func inchSpan(distancemm: CGFloat) -> CGFloat {
    let inchFromScreen: CGFloat = mmToInch(distancemm)
    let defaultAngle: CGFloat = degToRad(3)  // fovea's covered angle
    return 2 * inchFromScreen * tan(defaultAngle/2)
}

/// Returns a rectangle representing what should be seen by the participant's fovea
func getSeenRect(fromPoint point: NSPoint, zoomLevel: CGFloat) -> NSRect {
    let points = pointSpan(zoomLevel: zoomLevel, dpi: AppSingleton.getComputedDPI()!, distancemm: MidasManager.sharedInstance.lastValidDistance)
    
    var newOrigin = point
    newOrigin.x -= points / 2
    newOrigin.y -= points / 2
    let size = NSSize(width: points, height: points)
    return NSRect(origin: newOrigin, size: size)
}

/// Converts degrees to radians (xcode tan function is in radians)
func degToRad(deg: CGFloat) -> CGFloat {
    return deg * CGFloat(M_PI) / 180.0
}
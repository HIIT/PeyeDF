//
// Copyright (c) 2018 University of Helsinki, Aalto University
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

/// Given a point and a zoom level (PDFView's scaleFactor), return an array of points, separated by two points each (defaultStep),
/// that covers the defaultInchSpan vertically. The page rectangle (i.e. media box) is passed
/// in to avoid adding points which are not within 28 points (defaultMargin) (approximately 1cm in page space) to the returned array
func verticalFocalPoints(fromPoint point: NSPoint, zoomLevel: CGFloat, pageRect: NSRect) -> [NSPoint] {
    let defaultMargin: CGFloat = 28
    let defaultStep: CGFloat = 2
    
    let fitInRect = NSInsetRect(pageRect, defaultMargin, defaultMargin)
    
    var pointArray = [NSPoint]()
    let points = pointSpan(zoomLevel: zoomLevel, dpi: AppSingleton.getComputedDPI()!, distancemm: AppSingleton.eyeTracker?.lastValidDistance ?? 800)
    
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
func pointSpan(zoomLevel: CGFloat, dpi: Int, distancemm: CGFloat) -> CGFloat {
    return inchSpan(distancemm) * CGFloat(dpi) / zoomLevel
}

/// Returns how many inches should be covered by the participant's fovea at the given distance in
/// millimetres (at most, liberal estimate)
func inchSpan(_ distancemm: CGFloat) -> CGFloat {
    let inchFromScreen: CGFloat = mmToInch(distancemm)
    let defaultAngle: CGFloat = degToRad(3)  // fovea's covered angle ~3 degrees (liberal estimate, a more conservative estimate would be 1 degree)
    return 2 * inchFromScreen * tan(defaultAngle/2)
}

/// Returns a rectangle representing what should be seen by the participant's fovea
func getSeenRect(fromPoint point: NSPoint, zoomLevel: CGFloat) -> NSRect {
    let points = pointSpan(zoomLevel: zoomLevel, dpi: AppSingleton.getComputedDPI()!, distancemm: AppSingleton.eyeTracker?.lastValidDistance ?? 800)
    
    var newOrigin = point
    newOrigin.x -= points / 2
    newOrigin.y -= points / 2
    let size = NSSize(width: points, height: points)
    return NSRect(origin: newOrigin, size: size)
}

/// Converts degrees to radians (xcode tan function is in radians)
func degToRad(_ deg: CGFloat) -> CGFloat {
    return deg * CGFloat.pi / 180.0
}

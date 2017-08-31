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
import Cocoa
import os.log

class PDFPeerOverview: PDFOverview {
    
    /// Which colours are associated to which reading class (can be overridden in subclasses)
    override var markAnnotationColours: [ReadingClass: NSColor] { get {
        return [.low: PeyeConstants.colourPeerRead,
                .medium: PeyeConstants.annotationColourInteresting,
                .high: PeyeConstants.annotationColourCritical]
    } }
    
    /// Marks an area as read by the local user (.localPeer source) or network peer (.networkPeer source)
    func addArea(_ area: FocusArea, fromSource source: ClassSource) {
        guard source == .localPeer || source == .networkPeer else {
            if #available(OSX 10.12, *) {
                os_log("Adding areas for sources other than local or network peer is not supported", type: .error)
            }
            return
        }
        
        // TODO: intersecting of both local and network should be done "outside", ie when drawing.
        
        let readingClass: ReadingClass = source == .localPeer ? .medium : .low
        
        switch area.type {
        case .rect(let rect):
            DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
                [weak self] in
                self?.markings.addRect(rect, ofClass: readingClass, withSource: source, forPage: area.pageIndex)
                self?.markings.flattenRectangles_intersectToHigh()
                DispatchQueue.main.async {
                    [weak self] in
                    self?.refreshPage(atIndex: area.pageIndex, rect: rect)
                }
            }
        case .circle(let circle):
            markings.circles.append((circle, area.pageIndex, source))
            DispatchQueue.main.async {
                [weak self] in
                let rect = NSRect(circle: circle)
                self?.refreshPage(atIndex: area.pageIndex, rect: rect)
            }
        default:
            if #available(OSX 10.12, *) {
                os_log("Displaying read areas other than rects or circles is not implemented", type: .error)
            }
        }
    }
    
}

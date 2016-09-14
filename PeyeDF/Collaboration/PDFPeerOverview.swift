//
//  PDFPeerOverview.swift
//  PeyeDF
//
//  Created by Marco Filetti on 24/06/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation
import Cocoa

class PDFPeerOverview: PDFOverview {
    
    /// Which colours are associated to which reading class (can be overridden in subclasses)
    override var markAnnotationColours: [ReadingClass: NSColor] { get {
        return [.low: NSColor.green,  // TODO: use a better colour
                .medium: PeyeConstants.annotationColourInteresting,
                .high: PeyeConstants.annotationColourCritical]
    } }
    
    /// Marks an area as read by the local user
    func addAreaForLocal(_ area: FocusArea) {
        switch area.type {
        case .rect(let rect):
            DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
                self.markings.addRect(rect, ofClass: .medium, withSource: .localPeer, forPage: area.pageIndex)
                self.markings.flattenRectangles_intersectToHigh()
                DispatchQueue.main.async {
                    self.refreshPage(atIndex: area.pageIndex, rect: rect)
                }
            }
        default:
            AppSingleton.log.error("Displaying read areas other than rects is not implemented")
        }
    }
    
    /// Marks an area as read by a collaborator
    func addAreaForPeer(_ area: FocusArea) {
        switch area.type {
        case .rect(let rect):
            DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
                self.markings.addRect(rect, ofClass: .low, withSource: .networkPeer, forPage: area.pageIndex)
                self.markings.flattenRectangles_intersectToHigh()
                DispatchQueue.main.async {
                    self.refreshPage(atIndex: area.pageIndex, rect: rect)
                }
            }
        default:
            AppSingleton.log.error("Displaying read areas other than rects is not implemented")
        }
    }
}

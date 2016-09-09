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
        return [.Low: NSColor.greenColor(),  // TODO: use a better colour
                .Medium: PeyeConstants.annotationColourInteresting,
                .High: PeyeConstants.annotationColourCritical]
    } }
    
    /// Marks an area as read by the local user
    func addAreaForLocal(area: FocusArea) {
        switch area.type {
        case .Rect(let rect):
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
                self.markings.addRect(rect, ofClass: .Medium, withSource: .LocalPeer, forPage: area.pageIndex)
                self.markings.flattenRectangles_intersectToHigh()
                dispatch_async(dispatch_get_main_queue()) {
                    self.refreshPage(atIndex: area.pageIndex, rect: rect)
                }
            }
        default:
            AppSingleton.log.error("Displaying read areas other than rects is not implemented")
        }
    }
    
    /// Marks an area as read by a collaborator
    func addAreaForPeer(area: FocusArea) {
        switch area.type {
        case .Rect(let rect):
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
                self.markings.addRect(rect, ofClass: .Low, withSource: .NetworkPeer, forPage: area.pageIndex)
                self.markings.flattenRectangles_intersectToHigh()
                dispatch_async(dispatch_get_main_queue()) {
                    self.refreshPage(atIndex: area.pageIndex, rect: rect)
                }
            }
        default:
            AppSingleton.log.error("Displaying read areas other than rects is not implemented")
        }
    }
}
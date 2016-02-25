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
import Quartz

/// Enum representing something we can focus on, such as a point on a document (to
/// refer to a heading or bookmark) or a rect (to refer to a block of text).
enum FocusAreaType {
    case Page
    case Rect(NSRect)
    case Point(NSPoint)
    
    /// Creates itself from nsurlcomponents. If both a rect and point are found,
    /// rect takes precedence.
    init?(fromURLComponents comps: NSURLComponents) {
        
        guard let params = comps.parameterDictionary else {
            return nil
        }
        
        if let sr = params["rect"]?.withoutChars(["(", ")"]), r = NSRect(string: sr) {
            self = .Rect(r)
        } else if let sp = params["point"]?.withoutChars(["(", ")"]), p = NSPoint(string: sp) {
            self = .Point(p)
        } else {
            self = .Page
        }
    }
}

/// Represents a focus area, with a type and page.
struct FocusArea {
    let type: FocusAreaType
    let pageIndex: Int
    
    init(forPoint: NSPoint, onPage: Int) {
        self.type = .Point(forPoint)
        self.pageIndex = onPage
    }
    
    /// Fails if page is missing is below 0, or did not contain a type
    init?(fromURLComponents comps: NSURLComponents) {
        guard let params = comps.parameterDictionary, pageS = params["page"], pageIndex = Int(pageS) where pageIndex >= 0 else {
            AppSingleton.log.warning("Could not parse string: \(comps.string)")
            return nil
        }
        if let t = FocusAreaType(fromURLComponents: comps) {
            self.type = t
            self.pageIndex = pageIndex
        } else {
            return nil
        }
    }
}

/// Extends base pdf to support focus areas and focusing to them
extension MyPDFBase {
    
    /// Focuses on a rect / point on a given page (if the points are within the page,
    /// and the page exists).
    /// When focusing on a point, adds a half the frame size to y to "center" the desired point in the view.
    func focusOn(f: FocusArea) {
        guard f.pageIndex < self.document().pageCount() else {
           AppSingleton.log.warning("Attempted to focus on a non-existing page")
            return
        }
        
        let pdfpage = self.document().pageAtIndex(f.pageIndex)
        let pageRect = getPageRect(pdfpage)
        
        switch f.type {
        case let .Rect(r):
            guard NSContainsRect(pageRect, r) else {
               AppSingleton.log.warning("Attempted to focus on a rect outside bounds")
                return
            }
            
            let sel = pdfpage.selectionForRect(r)
            setCurrentSelection(sel, animate: false)
            scrollSelectionToVisible(self)
            setCurrentSelection(sel, animate: true)
            
        case let .Point(p):
            guard NSPointInRect(p, pageRect) else {
               AppSingleton.log.warning("Attempted to focus on a point outside bounds")
                return
            }
            
            // Get tiny rect of selected position
            var pointRect = NSRect(origin: p, size: NSSize())
            
            pointRect.origin.y += frame.size.height / 3
            goToRect(pointRect, onPage: pdfpage)
            
        case .Page:
            
            // Get beginning of page (x: 0, y: top)
            let pageRect = getPageRect(pdfpage)
            var p = pageRect.origin
            p.y = pageRect.origin.y + pageRect.height
            
            // Get tiny rect for beginning of page
            let pointRect = NSRect(origin: p, size: NSSize())
            
            goToRect(pointRect, onPage: pdfpage)
            
        }
    }
    
}

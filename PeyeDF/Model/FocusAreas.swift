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
enum FocusAreaType: CustomStringConvertible {
    
    /** - For page: '' (empty)
        - For point: 'x,y'
        - For rect: 'x,y,w,h'
    */
    var description: String { get {
        switch self {
        case .page:
            return ""
        case .rect(let r):
            return r.description
        case .point(let p):
            return p.description
        }
    } }
    
    case page
    case rect(NSRect)
    case point(NSPoint)
    
    /// Creates itself from nsurlcomponents. If both a rect and point are found,
    /// rect takes precedence.
    init?(fromURLComponents comps: URLComponents) {
        
        guard let params = comps.parameterDictionary else {
            return nil
        }
        
        if let sr = params["rect"]?.withoutChars(["(", ")"]), let r = NSRect(string: sr) {
            self = .rect(r)
        } else if let sp = params["point"]?.withoutChars(["(", ")"]), let p = NSPoint(string: sp) {
            self = .point(p)
        } else {
            self = .page
        }
    }
    
    /// Creates itself from a string in the format x,y or x,y,w,h (same format as
    /// description, empty String returns .page).
    init?(fromString string: String) {
        if let r = NSRect(string: string) {
            self = .rect(r)
        } else if let p = NSPoint(string: string) {
            self = .point(p)
        } else if string.isEmpty {
            self = .page
        } else {
            AppSingleton.log.error("Failed to parse '\(string)'")
            return nil
        }
    }
}

/// Represents a focus area, with a type and page.
struct FocusArea: CustomStringConvertible {
    
    /// When focusing on a point on a given page, the height
    /// of the frame will be multiplied by this factor and added
    /// to the point (so that the actual point will be slightly below
    /// the view's upper boundary)
    static let kPointFocusDistanceMult: CGFloat = 0.2
    
    /**
     Format:
     - For page: p (where p is page number)
     - For point: p:x,y
     - For rect: p:x,y,w,h
     */
    var description: String { get {
        switch self.type {
        case .page:
            return "\(self.pageIndex)"
        case .point(let p):
            return "\(self.pageIndex):\(p.description)"
        case .rect(let r):
            return "\(self.pageIndex):\(r.description)"
        }
    } }
    
    let type: FocusAreaType
    let pageIndex: Int
    
    init(forPoint: NSPoint, onPage: Int) {
        self.type = .point(forPoint)
        self.pageIndex = onPage
    }
    
    init(forRect: NSRect, onPage: Int) {
        self.type = .rect(forRect)
        self.pageIndex = onPage
    }
    
    init(forPage: Int) {
        self.pageIndex = forPage
        self.type = .page
    }
    
    /// Fails if page is missing is below 0, or did not contain a type
    init?(fromURLComponents comps: URLComponents) {
        guard let params = comps.parameterDictionary, let pageS = params["page"], let pageIndex = Int(pageS) , pageIndex >= 0 else {
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
    
    /// Creates itself from a string with the same format as description.
    init?(fromString string: String) {
        if let r = string.range(of: ":"), let pno = Int(string.substring(to: r.lowerBound)), let fatype = FocusAreaType(fromString: string.substring(from: r.upperBound)) {
            // there is range, extract page and focus area type
            self.pageIndex = pno
            self.type = fatype
        } else if let pno = Int(string) {
            // it is only valid if the string can be converted to int (page number)
            self.type = .page
            self.pageIndex = pno
        } else {
            AppSingleton.log.error("Failed to parse '\(string)'")
            return nil
        }
    }
}

/// Extends base pdf to support focus areas and focusing to them
extension PDFBase {
    
    /// Gets the point corresponding to a location in its own view.
    func getPoint(fromPointInView aPoint: NSPoint) -> FocusArea? {
        guard let doc = document, let activePage = self.page(for: aPoint, nearest: true) else {
            return nil
        }
        // Index for current page
        let pageIndex = doc.index(for: activePage)
        // Get location in "page space".
        let pagePoint = self.convert(aPoint, to: activePage)
        return FocusArea(forPoint: pagePoint, onPage: pageIndex)
    }
    
    /// Gets the point currently shown on the top left.
    func getCurrentPoint() -> FocusArea? {
        guard self.visiblePages() != nil else {
            return nil
        }
        let rects = getVisibleRects()
        let pages = getVisiblePageNums()
        guard rects.count > 0 && pages.count > 0 && rects.count == pages.count else {
            return nil
        }
        var newY = rects[0].origin.y + rects[0].size.height
        // check that we don't go outside top boundary. If so, get point at 10 points below top
        if let pageRect = document?.page(at: pages[0])?.bounds(for: .cropBox) {
            if newY > pageRect.size.height {
                newY = pageRect.size.height - 10
            }
        }
        var newPoint = rects[0].origin
        newPoint.y = newY
        return FocusArea(forPoint: newPoint, onPage: pages[0])
    }
    
    /// Focuses on a rect / point on a given page (if the points are within the page,
    /// and the page exists).
    /// When focusing on a point, adds a half the frame size to y to "center" the desired point in the view.
    /// - Parameter f: The area on which we want to focus
    /// - Parameter delay: Apply a delay for user feedback (a small amount by default)
    /// - Parameter offset: If true, when focusing on a point, slightly offset the
    ///    point so that there is some more page shown above the point.
    func focusOn(_ f: FocusArea, delay: Double = 0.5, offset: Bool = true) {
        guard f.pageIndex < self.document!.pageCount else {
           AppSingleton.log.warning("Attempted to focus on a non-existing page")
            return
        }
        
        let showTime = DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: showTime) {
            
            guard f.pageIndex < self.document!.pageCount, let pdfpage = self.document!.getPage(atIndex: f.pageIndex) else {
                return
            }
            
            let pageRect = self.getPageRect(pdfpage)
            
            switch f.type {
            case let .rect(r):
                guard NSContainsRect(pageRect, r) else {
                   AppSingleton.log.warning("Attempted to focus on a rect outside bounds")
                    return
                }
                
                let sel = pdfpage.selection(for: r)
                self.setCurrentSelection(sel, animate: false)
                self.scrollSelectionToVisible(self)
                self.setCurrentSelection(sel, animate: true)
                
            case let .point(p):
                guard NSPointInRect(p, pageRect) else {
                   AppSingleton.log.warning("Attempted to focus on a point outside bounds")
                    return
                }
                
                // Get tiny rect of selected position
                var pointRect = NSRect(origin: p, size: NSSize())
                
                if offset {
                    pointRect.origin.y += self.frame.size.height * FocusArea.kPointFocusDistanceMult
                }
                
                self.go(to: pointRect, on: pdfpage)
                
            case .page:
                
                // Get beginning of page (x: 0, y: top)
                let pageRect = self.getPageRect(pdfpage)
                var p = pageRect.origin
                p.y = pageRect.origin.y + pageRect.height
                
                // Get tiny rect for beginning of page
                let pointRect = NSRect(origin: p, size: NSSize())
                
                self.go(to: pointRect, on: pdfpage)
                
            }
        }
    }
    
}

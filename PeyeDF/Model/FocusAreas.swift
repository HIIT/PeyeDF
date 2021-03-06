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
import Cocoa
import Quartz

/// A perfectly round circle, with a centre and a radius
struct Circle: CustomStringConvertible {
    let centre: CGPoint
    let radius: CGFloat
    
    init(x: CGFloat, y: CGFloat, r: CGFloat) {
        self.centre = CGPoint(x: x, y: y)
        self.radius = r
    }
    
    /// Creates a circle from a point and a radius using the string 'x,y,r'.
    init?(string: String) {
        if let spl = string.split(","), spl.count == 3 {
            let nf = NumberFormatter()
            nf.localizesFormat = false  // to be locale-independent
            if let x = nf.number(from: spl[0]) as? CGFloat,
                let y = nf.number(from: spl[1]) as? CGFloat,
                let r = nf.number(from: spl[2]) as? CGFloat {
                self.centre = CGPoint(x: x, y: y)
                self.radius = r
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    var description: String { get {
        return centre.description + ",\(radius)"
    } }
}

/// Enum representing something we can focus on, such as a point on a document (to
/// refer to a heading or bookmark) or a rect (to refer to a block of text).
enum FocusAreaType: CustomStringConvertible {
    
    /** - For page: '' (empty)
        - For point: 'x,y'
        - For rect: 'x,y,w,h'
        - For circle: 'x,y,r'
    */
    var description: String { get {
        switch self {
        case .page:
            return ""
        case .rect(let r):
            return r.description
        case .point(let p):
            return p.description
        case .circle(let c):
            return c.description
        }
    } }
    
    case page
    case rect(NSRect)
    case point(NSPoint)
    case circle(Circle)
    
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
        } else if let sp = params["circle"]?.withoutChars(["(", ")"]), let c = Circle(string: sp) {
            self = .circle(c)
        } else {
            self = .page
        }
    }
    
    /// Creates itself from a string in the format x,y or x,y,w,h or x,y,r (same format as
    /// description, empty String returns .page).
    init?(fromString string: String) {
        if let r = NSRect(string: string) {
            self = .rect(r)
        } else if let p = NSPoint(string: string) {
            self = .point(p)
        } else if let c = Circle(string: string) {
            self = .circle(c)
        } else if string.isEmpty {
            self = .page
        } else {
            return nil
        }
    }
}

/// Represents a focus area, with a type and page.
struct FocusArea: CustomStringConvertible {
    
    /// Returns a rect that encloses the corresponding area.
    /// Returns a non-nil value only the area corresponds to a rect or a circle.
    var enclosingRect: NSRect? { get {
        switch  self.type {
        case .rect(let r):
            return r
        case .circle(let c):
            return NSRect(circle: c)
        default:
            return nil
        }
    } }
        
    /**
     Format:
     - For page: p (where p is page number)
     - For point: p:x,y
     - For rect: p:x,y,w,h
     - For circle: p:x,y,r
     */
    var description: String { get {
        switch self.type {
        case .page:
            return "\(self.pageIndex)"
        case .point(let p):
            return "\(self.pageIndex):\(p.description)"
        case .rect(let r):
            return "\(self.pageIndex):\(r.description)"
        case .circle(let c):
            return "\(self.pageIndex):\(c.description)"
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
    
    init(forCircle: Circle, onPage: Int) {
        self.type = .circle(forCircle)
        self.pageIndex = onPage
    }
    
    init(forPage: Int) {
        self.pageIndex = forPage
        self.type = .page
    }
    
    /// Fails if page is missing is below 0, or did not contain a type.
    init?(fromURLComponents comps: URLComponents) {
        guard let params = comps.parameterDictionary, let pageS = params["page"], let pageIndex = Int(pageS) , pageIndex >= 0 else {
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
        if let r = string.range(of: ":"), let pno = Int(String(string[..<r.lowerBound])), let fatype = FocusAreaType(fromString: String(string[r.upperBound...])) {
            // there is range, extract page and focus area type
            self.pageIndex = pno
            self.type = fatype
        } else if let pno = Int(string) {
            // it is only valid if the string can be converted to int (page number)
            self.type = .page
            self.pageIndex = pno
        } else {
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
    
    /// Gets the point currently shown on the centre (left margin).
    func getCurrentPoint() -> FocusArea? {
        let midPoint = NSPoint(x: self.bounds.width / 2, y: self.bounds.height / 2)
        guard let page = self.page(for: midPoint, nearest: true), let pageIndex = document?.index(for: page) else {
            return nil
        }
        
        let pagePoint = convert(midPoint, to: page)
        let pageRect = page.bounds(for: .cropBox)
        return FocusArea(forPoint: pageRect.intersectWith(point: pagePoint), onPage: pageIndex)
    }
    
    /// Focuses on a rect / point on a given page (if the points are within the page,
    /// and the page exists).
    /// When focusing on a point (or circle centre), scrolls only vertically so that the point is that
    /// at the vertical centre of the page.
    ///
    /// - Parameter f: The area on which we want to focus
    /// - Parameter delay: Apply a delay for user feedback (a small amount by default)
    func focusOn(_ f: FocusArea, delay: Double = 0.5) {
        guard let document = self.document, f.pageIndex < document.pageCount else {
            return
        }
        
        let showTime = DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: showTime) {
            
            guard f.pageIndex < document.pageCount, let pdfpage = document.getPage(atIndex: f.pageIndex) else {
                return
            }
            
            let pageRect = self.getPageRect(pdfpage)
            
            switch f.type {
            case let .rect(r):
                guard NSContainsRect(pageRect, r) else {
                    return
                }
                
                let sel = pdfpage.selection(for: r)
                self.setCurrentSelection(sel, animate: false)
                self.scrollSelectionToVisible(self)
                self.setCurrentSelection(sel, animate: true)
                
            case let .point(p):
                
                let viewOnPage = self.convert(self.bounds, to: pdfpage)
                let focusPoint = NSPoint(x: 0, y: p.y + viewOnPage.size.height / 2)
                
                // Get tiny rect of position
                let pointRect = NSRect(origin: pageRect.intersectWith(point: focusPoint), size: NSSize())
                
                self.go(to: pointRect, on: pdfpage)
                
            case let .circle(c):
                
                let viewOnPage = self.convert(self.bounds, to: pdfpage)
                var focusPoint = NSPoint(x: 0, y: c.centre.y + viewOnPage.size.height / 2)
                
                focusPoint = pageRect.intersectWith(point: focusPoint)
                
                // Get tiny rect of position
                let pointRect = NSRect(origin: pageRect.intersectWith(point: focusPoint), size: NSSize())
                                
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

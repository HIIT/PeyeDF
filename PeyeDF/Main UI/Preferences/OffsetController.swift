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

import Cocoa

class OffsetController: NSViewController {
    
    @IBOutlet weak var overlayView: OffsetOverlayView!
    @IBOutlet weak var currentOffsetLabel: NSTextField!
    @IBOutlet weak var lastUpdateLabel: NSTextField!
    
    let previousFixDelegate = AppSingleton.eyeTracker?.fixationDelegate
    var previousOffset = AppSingleton.eyeOffset
    
    @IBAction func resetPress(_ sender: NSButton) {
        AppSingleton.eyeOffset = [0, 0]
        updateLabels()
    }
    
    /// Updates the desired offset by subtracting the obtained fixation point
    /// from the desired mouse point.
    /// Both points should be provided using origin as top left.
    func correctPoint(fixationPoint: NSPoint, mousePoint: NSPoint) {
        previousOffset = AppSingleton.eyeOffset
        
        // remove offset from fixation before continuing (assume previous fixation was already corrected)
        var correctedFixation = fixationPoint
        correctedFixation.x -= previousOffset[0]
        correctedFixation.y -= previousOffset[1]
        
        let offsetx = mousePoint.x - correctedFixation.x
        let offsety = mousePoint.y - correctedFixation.y
        
        let newOffset: [CGFloat] = [offsetx, offsety]
        AppSingleton.eyeOffset = newOffset
        updateLabels()
    }
    
    func updateLabels() {
        DispatchQueue.main.async {
            self.currentOffsetLabel.stringValue = "\(Int(round(AppSingleton.eyeOffset[0]))) , \(Int(round(AppSingleton.eyeOffset[1])))"
            let diffx = AppSingleton.eyeOffset[0] - self.previousOffset[0]
            let diffy = AppSingleton.eyeOffset[1] - self.previousOffset[1]
            let diff: [CGFloat] = [diffx, diffy]
            self.lastUpdateLabel.stringValue = "\(Int(round(diff[0]))) , \(Int(round(diff[1])))"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateLabels()
    }
    
    override func viewDidAppear() {
        AppSingleton.eyeTracker?.fixationDelegate = overlayView
    }
    
    override func viewWillDisappear() {
        AppSingleton.eyeTracker?.fixationDelegate = previousFixDelegate
    }
    
}

class OffsetOverlayView: NSView, FixationDataDelegate {
    
    var fixBall: CALayer?
    let fixSize: CGFloat = 16
    let fixationColor: CGColor = #colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1).cgColor
    
    var lastFixationPoint = CGPoint()

    override var wantsUpdateLayer: Bool { get {
        return true
    } }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        completeInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        completeInit()
    }
    
    /// By pressing mouse down we correct the fixation from the current point to the mouse point, both in screen coordinates.
    /// (This method flips mouse y coordinate since its origin is the opposite of the eye coordinate).
    override func mouseDown(with event: NSEvent) {
        let locationInView = self.convert(event.locationInWindow, from: self.window!.contentViewController!.view)
        
        let cx = locationInView.x - fixSize / 2
        let cy = locationInView.y - fixSize / 2
        let newPoint = CGPoint(x: cx, y: cy)
        
        DispatchQueue.main.async {
            self.fixBall?.position = newPoint
        }
        
        let tinySize = NSSize(width: 1, height: 1)
        let tinyRect = NSRect(origin: event.locationInWindow, size: tinySize)
        var mousePoint = self.window!.convertToScreen(tinyRect)
        
        // flip mouse y coor
        mousePoint.origin.y = self.window!.screen!.frame.size.height - mousePoint.origin.y
        
        (self.window?.contentViewController as? OffsetController)?.correctPoint(fixationPoint: lastFixationPoint, mousePoint: mousePoint.origin)
    }
    
    /// Convenience function to complete initialization
    func completeInit() {
        self.wantsLayer = true
        
        let circle = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: fixSize, height: fixSize), transform: nil)
        
        let layer = CAShapeLayer()
        layer.path = circle
        layer.fillColor = fixationColor
        self.layer?.addSublayer(layer)
        fixBall = layer
        
        self.layerContentsRedrawPolicy = NSView.LayerContentsRedrawPolicy.onSetNeedsDisplay
    }
    
    func receiveNewFixationData(_ newData: [FixationEvent]) {
        let fixEv = newData[0]
        
        // convert to screen point and flip it (smi and os x have y coordinate flipped.
        // save fixation point before flipping y.
        var screenPoint = NSPoint(x: fixEv.positionX, y: fixEv.positionY)
        lastFixationPoint = screenPoint
        
        screenPoint.y = AppSingleton.screenRect.height - screenPoint.y
        
        let tinySize = NSSize(width: 1, height: 1)
        let tinyRect = NSRect(origin: screenPoint, size: tinySize)
        
        let rectInWindow = self.window!.convertFromScreen(tinyRect)
        let rectInView = self.convert(rectInWindow, from: self.window!.contentViewController!.view)
        let pointInView = rectInView.origin
        
        //  return if the point is outside this view
        if pointInView.x < 0 || pointInView.y < 0 || pointInView.x > frame.width || pointInView.y > frame.height {
            return
        }
        
        let cx = pointInView.x - fixSize / 2
        let cy = pointInView.y - fixSize / 2
        let newPoint = CGPoint(x: cx, y: cy)
        DispatchQueue.main.async {
            self.fixBall?.position = newPoint
        }
    }
    
}

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

import Cocoa

/// Implementation of a stack view that automates animations when adding / removing items
class AnimatedStack: NSStackView {
    
    static let timingFunc = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)

    func animateViewIn(_ theView: NSView) {
        theView.alphaValue = 0
        addView(theView, in: .top)
        NSAnimationContext.runAnimationGroup({
            context in
            context.duration = 0.5
            context.allowsImplicitAnimation = true
            context.timingFunction = AnimatedStack.timingFunc
            theView.alphaValue = 1
            self.window!.layoutIfNeeded()
        }, completionHandler: {
        })
    }
    
    func animateViewOut(_ theView: NSView) {
        NSAnimationContext.runAnimationGroup({
            context in
            context.duration = 0.2
            context.timingFunction = AnimatedStack.timingFunc
            theView.animator().alphaValue = 0
            self.window!.layoutIfNeeded()
            }, completionHandler: {
                self.removeView(theView)
                NSAnimationContext.runAnimationGroup({
                    context in
                    context.timingFunction = AnimatedStack.timingFunc
                    context.duration = 0.3
                    context.allowsImplicitAnimation = true
                    self.window!.layoutIfNeeded()
                }, completionHandler: {
                })
        })
    }
    
    func removeAllViews() {
        for v in self.views {
            self.removeView(v)
        }
    }
}

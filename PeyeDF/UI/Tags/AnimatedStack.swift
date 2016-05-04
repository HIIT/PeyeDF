//
//  AnimatedStack.swift
//  TagStack
//
//  Created by Marco Filetti on 26/02/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Cocoa

/// Implementation of a stack view that automates animations when adding / removing items
class AnimatedStack: NSStackView {
    
    static let timingFunc = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)

    func animateViewIn(theView: NSView) {
        theView.alphaValue = 0
        addView(theView, inGravity: .Top)
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
    
    func animateViewOut(theView: NSView) {
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

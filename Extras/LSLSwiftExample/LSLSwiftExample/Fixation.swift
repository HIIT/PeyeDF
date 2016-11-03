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

/// Events in SMI terminology include fixations

import Foundation

struct FixationEvent: Equatable, FloatDictInitializable {
    var eye: Eye
    var startTime: Int
    var endTime: Int
    var duration: Int
    var positionX: Double
    var positionY: Double
    var unixtime: Int
    
    init(dict: [String: Float]) {
        self.eye = Eye(rawValue: Int(dict["eye"]!))!
        self.startTime = 0
        self.duration = 0
        self.endTime = 0
        self.positionX = 0
        self.unixtime = 0
        self.positionY = 1
    }
}

func == (lhs: FixationEvent, rhs: FixationEvent) -> Bool {
    return lhs.eye == rhs.eye &&
           lhs.startTime == rhs.startTime &&
           lhs.endTime == rhs.endTime &&
           lhs.duration == rhs.duration &&
           lhs.positionX == rhs.positionX &&
           lhs.positionY == rhs.positionY &&
           lhs.unixtime == rhs.unixtime
}

/// Eye (left or right). Using same coding as SMI_LSL data streaming.
public enum Eye: Int {
    case left = -1
    case right = 1
}


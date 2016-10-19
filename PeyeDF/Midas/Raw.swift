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

// Raw data from eye tracking (used to track user's head position)

import Foundation

struct RawEyePosition {
    var timestamp: Int
    var EyePositionX: Double
    var EyePositionY: Double
    var EyePositionZ: Double  // eye distance from screen in mm
    
    /// Creates a new eye position, using the last available element in the json
    init(fromLastInJSON json: JSON, dominantEye: Eye) {
        timestamp = json[0]["return"]["timestamp"]["data"].arrayValue.last!.intValue
        var eyeString: String
        switch dominantEye {
        case .left:
            eyeString = "left"
        case .right:
            eyeString = "right"
        }
        EyePositionX = json[0]["return"]["\(eyeString)EyePositionX"]["data"].arrayValue.last!.doubleValue
        EyePositionY = json[0]["return"]["\(eyeString)EyePositionY"]["data"].arrayValue.last!.doubleValue
        EyePositionZ = json[0]["return"]["\(eyeString)EyePositionZ"]["data"].arrayValue.last!.doubleValue
    }
    
    /// Returns true if this eye position is actually missing (eyes closed, or unseen)
    func zeroed() -> Bool {
        if EyePositionX == 0 && EyePositionY == 0 && EyePositionZ == 0 {
            return true
        }
        return false
    }
    
    /// Returns this eye position as a dictionary. Has keys "xpos", "ypos" and "zpos"
    func asDict() -> [String: Double] {
        return ["xpos": EyePositionX, "ypos": EyePositionY, "zpos": EyePositionZ]
    }
}

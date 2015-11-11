//
//  Raw.swift
//  PeyeDF
//
//  Created by Marco Filetti on 05/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

// Raw data from eye tracking

import Foundation

struct SMIEyePosition {
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
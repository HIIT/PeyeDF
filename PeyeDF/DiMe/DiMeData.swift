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

/// This class is made for subclassing. It represents data common to all dime objects (see /dime-server/src/main/java/fi/hiit/dime/data/DiMeData.java in the dime project).
class DiMeBase: NSObject, Dictionariable {
    
    /// Main dictionary storing all data
    ///
    /// **Important**: endpoint classes (Event, InformationElement as subclasses) must set these two keys, in order to be decoded by dime:
    /// - @type
    /// - type
    var theDictionary = [String : Any]()
    
    override init() {
        super.init()
    }
    
    /// Simply returns the dictionary. Can be overridden by subclasses that want
    /// to edit the dictionary before sending it.
    func getDict() -> [String : Any] {
        return theDictionary
    }
}

/// Represents a simple range with a start and end value
struct DiMeRange: Dictionariable, Equatable {
    var min: NSNumber
    var max: NSNumber
    
    /// Returns min and max in a dict
    func getDict() -> [String : Any] {
        var retDict = [String : Any]()
        retDict["min"] = min
        retDict["max"] = max
        return retDict
    }
}

func == (lhs: DiMeRange, rhs: DiMeRange) -> Bool {
    return lhs.max == rhs.max &&
        lhs.min == rhs.min
}


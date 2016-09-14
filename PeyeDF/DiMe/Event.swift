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

/// Note: this class is for subclassing and should not be used directly.
/// subclasses must implement the DiMeAble protocol.
class Event: DiMeBase {
    let startDate: Date
    fileprivate (set) var id: Int?
    
    /// Must be called by subclasses that create an event starting now
    override init() {
        startDate = Date()
        super.init()
        
        // Make creation date
        theDictionary["start"] = PeyeConstants.diMeDateFormatter.string(from: startDate)
        theDictionary["actor"] = "PeyeDF"
        if let hostname = Host.current().name {
            theDictionary["origin"] = hostname
        }
        
        // set dime-required fields (these are defaults that can be overwritten by subclasses)
        theDictionary["@type"] = "Event"
        theDictionary["type"] = "http://www.hiit.fi/ontologies/dime/#Event"
    }
    
    /// Must be called by subclasses that create an event with a specific starting date
    init(withStartDate date: Date) {
        startDate = date
        super.init()
        
        // Make creation date
        theDictionary["start"] = PeyeConstants.diMeDateFormatter.string(from: startDate)
        theDictionary["actor"] = "PeyeDF"
        if let hostname = Host.current().name {
            theDictionary["origin"] = hostname
        }
        
        // set dime-required fields (these are defaults that can be overwritten by subclasses)
        theDictionary["@type"] = "Event"
        theDictionary["type"] = "http://www.hiit.fi/ontologies/dime/#Event"
    }
    
    /// Sets the id of this event. If an id is given, dime will replace the previous event which had this id.
    func setId(_ newId: Int) {
        id = newId
        theDictionary["id"] = newId
    }
    
    /// Set an end date for this item (otherwise, won't be submitted)
    func setEnd(_ endDate: Date) {
        theDictionary["end"] = PeyeConstants.diMeDateFormatter.string(from: endDate)
    }
}

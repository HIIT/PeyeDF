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

/// The LSLXMLParserDelegate is used to parse an XML from an LSL stream.
/// It will obtain the number of channels and the channel indices that are associated to them.
class LSLXMLParserDelegate: NSObject, XMLParserDelegate {
    
    /// Channel name (key) returns channel index
    private(set) var channelIndexes = [String: Int]()
    
    /// Number of channels
    var nOfChannels: Int { get {
        return channelIndexes.keys.count
    } }
    
    /// Converts a buffer to a dictionary in which data is indexed by strings rather than int
    func dictBuffer(inData: [Float]) -> [String: Float] {
        var outDict = [String: Float]()
        for k in channelIndexes.keys {
            outDict[k] = inData[channelIndexes[k]!]
        }
        return outDict
    }
    
    // MARK: - Parser delegate
    // Associates every channel string to an index
    
    private var doingLabel = false
    private var count = -1
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "label" {
            doingLabel = true
            count += 1
        } else {
            doingLabel = false
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "label" {
            doingLabel = false
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if doingLabel {
            channelIndexes[string] = count
        }
    }

}

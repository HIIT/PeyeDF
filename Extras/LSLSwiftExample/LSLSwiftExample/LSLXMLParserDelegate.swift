//
//  LSLXMLParser.swift
//  LSLSwiftExample
//
//  Created by Marco Filetti on 01/11/2016.
//  Copyright © 2016 Aalto University. All rights reserved.
//

import Foundation

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
    
    var doingLabel = false
    var count = -1
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "label" {
            doingLabel = true
            count += 1
        } else {
            doingLabel = false
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if doingLabel {
            channelIndexes[string] = count
        }
    }

}

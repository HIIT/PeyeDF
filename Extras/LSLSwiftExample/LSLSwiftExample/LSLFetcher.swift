//
//  LSLFetcher.swift
//  LSLSwiftExample
//
//  Created by Marco Filetti on 03/11/2016.
//  Copyright © 2016 Aalto University. All rights reserved.
//

import Foundation

/// Adopters of this protocol can be initialized by using a [String: Float] dictionary
/// (data from LSL, in which the key is the channel name and float the given sample).
protocol FloatDictInitializable {
    
    init(dict: [String: Float])
    
}

/// The LSLFetcher is a generic protocol used to fetch data from LSL and return associated types.
/// Must call start on creation.
protocol LSLFetcher: class {
    
    /// Must be NSString to use the utf8String instance variable.
    /// - Attention: Stream names must be unique across the app and in LSL (i.e. there can only be one stream name and it must be the same in both LSL and in this app).
    var streamName: NSString { get }
    
    associatedtype EyeDataType: FloatDictInitializable
    
    var dataCallback: (EyeDataType?) -> Void { get }
 
    /// Set to false to stop fetching data
    var active: Bool { get set }
}

extension LSLFetcher {
    
    func start() {
        
        guard !active else {
            return
        }
        
        active = true
        
        // timeout for operations (seconds)
        let timeout: Double = 5
        
        // stream information pointer
        var inf: lsl_streaminfo? = nil
        
        // get the stream name that matches our name
        let found = lsl_resolve_byprop(&inf, 1, UnsafeMutablePointer<Int8>(mutating: ("name" as NSString).utf8String), UnsafeMutablePointer<Int8>(mutating: streamName.utf8String), 1, timeout)
        
        guard found == 1, let streamInfo = inf else {
            Swift.print("Failed to find stream")  // TODO: change to log
            return
        }
        
        
        // With a buffer of 1 minute of data, fill inlet
        let inlet = lsl_create_inlet(streamInfo, 60, LSL_NO_PREFERENCE, 1)
        
        // Retrieve full information from stream (required)
        let fullinfo = lsl_get_fullinfo(inlet, LSL_FOREVER, nil)
        
        // Put information in the `xml` pointer
        let xml = lsl_get_xml(fullinfo)
        
        /// Parse xml to find channel names
        let parsed = XMLParser(data: String(utf8String: xml!)!.data(using: .utf8)!)
        let parsDelegate = LSLXMLParserDelegate()
        parsed.delegate = parsDelegate
        parsed.parse()
        
        var errcode: Int32 = 0
        
        lsl_open_stream(inlet, timeout, &errcode)
        
        guard errcode == 0 else {
            Swift.print("Failed to open LSL stream. Code: \(errcode)")  // TODO: change to log / display message
            return
        }
        
        /// Dispatch queue on which to repeatedly pull LSL data
        let queue = DispatchQueue(label: "LSLFetcher.\(streamName)", qos: .default)
        
        let nOfChannels = parsDelegate.nOfChannels
        var buffer = Array<Float>(repeating: 0.0, count: nOfChannels)
        
        queue.async {
            while self.active {
                let timestamp = lsl_pull_sample_f(inlet, &buffer, Int32(nOfChannels), timeout, &errcode)
                if errcode != 0 {
                    Swift.print("Error while fetching a sample from stream \(self.streamName)")
                }
                if timestamp != 0 {
                    DispatchQueue.global(qos: .default).async {
                        let convertedData = EyeDataType(dict: parsDelegate.dictBuffer(inData: buffer))
                        self.dataCallback(convertedData)
                    }
                } else {
                    DispatchQueue.global(qos: .default).async {
                        self.dataCallback(nil)
                    }
                }
            }
        }
    }
    
    /// Stops fetching data. Same as setting active to false.
    func stop() {
        active = false
    }
    
}

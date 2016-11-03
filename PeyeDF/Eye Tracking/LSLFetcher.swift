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

// NOTE: -------
//
// If no streams are found, even if everything seems correct, one may need to place a file
// called lsl_api.cfg in the ~/lsl_api/ folder.
// The contents of the lsl_api.cfg can be something like this:
// 
// [lab]
// KnownPeers = {10.211.55.5}
//
// Where KnownPeers contains the IP addresses of the machines pushing LSL samples.
//
// The lsl_api.cfg must contain the IP(s) of the streams we are trying to connect to.
// See https://github.com/sccn/labstreaminglayer/wiki/NetworkConnectivity.wiki
//
// -------------


/// Adopters of this protocol can be initialized by using a [String: Float] dictionary
/// (such as data from LSL, in which the key is the LSL channel name and float the individual sample corresponding to that channel).
protocol FloatDictInitializable {
    
    init(floatDict: [String: Float])
    
}

/// The LSLFetcher constantly fetches data from an LSL stream with a given name.
/// It is assumed this stream only fetches data of a given type 'EyeDataType' from the stream.
/// Creates EyeDataType (FloatDictInitializable adopters) as soon as as some data is pulled from
/// the stream, and calls the callback with the result.
class LSLFetcher<EyeDataType: FloatDictInitializable> {
    
    /// The LSL stream name associated to this Fetcher.
    /// Must be NSString to use the utf8String instance variable.
    /// - Attention: Stream names must be unique across the app and in LSL (i.e. there can only be one stream name and it must be the same in both LSL and in this app).
    let streamName: NSString
    
    /// Set to this to false (or call stop()) to stop fetching data
    var active: Bool = false
    
    /// XML Description found in the stream
    var description: String = "<No streams found>"
    
    /// The function that will be called every time a sample is found in the data.
    /// Callbacks are dispatched to the global default priority queue.
    private let dataCallback: (Double, EyeDataType?) -> Void
    
    /// Creates a Fetcher that pulls data from the LSL stream with the given name.
    /// The fetcher will repeatedly call the dataCallback with every sample obtained from
    /// the stream, until stopped.
    init(name: String, dataCallback: @escaping (Double, EyeDataType?) -> Void) {
        self.streamName = name as NSString
        self.dataCallback = dataCallback
    }
    
    /// Starts to fetch data from the LSL stream.
    /// Returns true if operation was successful, false if not.
    func start() -> Bool {
        
        guard !active else {
            return false
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
            return false
        }
        
        // With a buffer of 1 minute of data, however accepting only one chunk (third parameter), fill buffer
        let inlet = lsl_create_inlet(streamInfo, 60, 1, 1)
        
        // Retrieve full information from stream (required)
        let fullinfo = lsl_get_fullinfo(inlet, LSL_FOREVER, nil)
        
        // Put information in the `xml` pointer
        let xml = lsl_get_xml(fullinfo)
        
        /// Parse xml to find channel names
        let parsed = XMLParser(data: String(utf8String: xml!)!.data(using: .utf8)!)
        let parsDelegate = LSLXMLParserDelegate()
        parsed.delegate = parsDelegate
        parsed.parse()

        // Convert pointer to Swift String
        if let description = String(utf8String: xml!) {
            self.description = description
        }

        var errcode: Int32 = 0
        
        lsl_open_stream(inlet, timeout, &errcode)
        
        guard errcode == 0 else {
            Swift.print("Failed to open LSL stream. Code: \(errcode)")  // TODO: change to log / display message
            return false
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
                        let convertedData = EyeDataType(floatDict: parsDelegate.dictBuffer(inData: buffer))
                        self.dataCallback(timestamp, convertedData)
                    }
                } else {
                    DispatchQueue.global(qos: .default).async {
                        self.dataCallback(0, nil)
                    }
                }
            }
        }
        
        return true
    }
    
    /// Stops fetching data. Same as setting active to false.
    func stop() {
        active = false
    }
    
}

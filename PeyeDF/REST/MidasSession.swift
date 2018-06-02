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
import os.log

/// Convenience class to perform MIDAS RESTful fetches
class MidasSession {
    
    /// Address of midas server
    static let midasAddress: String = "127.0.0.1"
    
    /// Port of midas server
    static let midasPort: String = "8085"
        
    /// Tests midas by querying the test url.
    /// Callbacks the given function with true if the test succeeded.
    static func test(callback: @escaping (Bool) -> Void) {
        let urlSession = URLSession(configuration: .default)
        
        let testURL = URL(string: "http://\(midasAddress):\(midasPort)/test")!
        let urlRequest = URLRequest(url: testURL, timeoutInterval: 5)
        
        urlSession.dataTask(with: urlRequest) {
            data, response, error in
            if error == nil {
                callback(true)
            } else {
                if #available(OSX 10.12, *) {
                    let errorDesc = error?.localizedDescription ?? "<nil>"
                    os_log("Failed to connect to Midas: %@", type: .fault, errorDesc)
                }
                callback(false)
            }
        }.resume()
    }
    
    /// Fetches a chunk of data from Midas. Suffix specifies the exact path
    /// (to get exactly the sensor / channel we want).
    /// Calls the given callback with the returned JSON, if the operation
    /// succeeded, nil otherwise.
    static func fetch(suffix: String, callback: @escaping (JSON?, Error?) -> Void) {
        let urlSession = URLSession(configuration: .ephemeral)
        
        let baseAddress = "http://\(midasAddress):\(midasPort)/"
        let fullAddress = (baseAddress + suffix).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let fullURL = URL(string: fullAddress)!
        let urlRequest = URLRequest(url: fullURL, timeoutInterval: 2)
        
        urlSession.dataTask(with: urlRequest) {
            data, response, error in
            if let data = data, error == nil {
                callback(JSON(data: data), nil)
            } else {
                if #available(OSX 10.12, *) {
                    os_log("Failed to fetch Midas data for %@", type: .fault, fullAddress)
                }
                callback(nil, error)
            }
        }.resume()
    }
}

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

class CrossRefSession {
    fileprivate static let urlSession = URLSession(configuration: .default)
    
    /// Fetches metedata for a given doi using CrossRef, and calls a callback with the result
    /// (nil if failed)
    static func fetch(doi: String, callback: @escaping (JSON?) -> Void) {
        guard let url = URL(string: "http://api.crossref.org/works/\(doi)") else {
            callback(nil)
            return
        }
        let urlRequest = URLRequest(url: url, timeoutInterval: 10)
        urlSession.dataTask(with: urlRequest) {
            data, response, error in
            if let data = data, error == nil {
                callback(JSON(data: data))
            } else {
                callback(nil)
            }
        }.resume()
    }
}

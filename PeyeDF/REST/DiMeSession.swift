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

enum RESTError: Error {
    case invalidUrl
}

/// Contains configurations for the DiMe API using the native macOS URL Loading System
class DiMeSession {
    
    /// Is true if there is a connection to DiMe, and can be used
    private(set) static var dimeAvailable: Bool = false { didSet {
        NotificationCenter.default.post(name: PeyeConstants.diMeConnectionNotification, object: self, userInfo: ["available": dimeAvailable])
    } }
    
    /// Returns dime server url
    static var dimeUrl: String = {
        return UserDefaults.standard.value(forKey: PeyeConstants.prefDiMeServerURL) as! String
    }()
    
    /// Returns HTTP headers used for DiMe connection
    static var dimeHeaders: [String: String] { get {
        let user: String = UserDefaults.standard.value(forKey: PeyeConstants.prefDiMeServerUserName) as! String
        let password: String = UserDefaults.standard.value(forKey: PeyeConstants.prefDiMeServerPassword) as! String
        
        let credentialData = "\(user):\(password)".data(using: String.Encoding.utf8)!
        let base64Credentials = credentialData.base64EncodedString(options: [])
        
        return ["Authorization": "Basic \(base64Credentials)"]
    } }
    
    /// Shared url session used to push / fetch data
    fileprivate static var sharedSession: URLSession? = URLSession(configuration: getConfiguration()) { willSet {
        sharedSession?.finishTasksAndInvalidate()
    } }

    /// Updates the configuration (in case username and password change, for example)
    static func getConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = DiMeSession.dimeHeaders
        configuration.timeoutIntervalForRequest = 4 // seconds
        configuration.timeoutIntervalForResource = 4
        return configuration
    }
    
    static func fetch(urlString: String, callback: @escaping (JSON?, Error?) -> Void) {
        guard let url = URL(string: urlString) else {
            callback(nil, RESTError.invalidUrl)
            return
        }
        // TODO: check shared session is not nil before continuing
        DiMeSession.sharedSession?.dataTask(with: url) {
            data, response, error in
            if let data = data, error == nil {
                callback(JSON(data: data), nil)
            } else if let error = error {
                callback(nil, error)
            } else {
                callback(nil, nil)
            }
        }.resume()
    }
    
    static func push(urlString: String, jsonDict: [String: Any], callback: @escaping (JSON?, Error?) -> Void) {
        guard let url = URL(string: urlString) else {
            callback(false, RESTError.invalidUrl)
            return
        }
        do {
            var urlRequest = URLRequest(url: url, timeoutInterval: 5.0)
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            DiMeSession.sharedSession?.dataTask(with: urlRequest) {
                data, _, error in
                if let error = error {
                    AppSingleton.log.error("Error while uploading json: \(error)")
                    callback(nil, error)
                } else if let data = data {
                    callback(JSON(data: data), nil)
                } else {
                    callback(nil, nil)
                }
            }.resume()
        } catch {
            AppSingleton.log.error("Failed to convert to json: \(error)")
        }
    }
    
    /// Attempts to connect to dime. Sends a notification if we succeeded / failed.
    /// Also calls the given callback with a boolean (which is true if operation succeeded).
    static func dimeConnect(_ callback: ((Bool, Error?) -> Void)? = nil) {
        
        let server_url = DiMeSession.dimeUrl

        DiMeSession.fetch(urlString: server_url + "/ping") {
            json, error in
            if let json = json, error == nil, let response = json["message"].string, response == "pong" {
                dimeAvailable = true
                callback?(true, nil)
            } else {
                // connection failed
                if let error = error {
                    AppSingleton.log.error("Error while connecting to (pinging) DiMe. Error message:\n\(error)")
                } else {
                    AppSingleton.log.error("Error while connecting to (pinging) DiMe. No error returned.")
                }
                callback?(false, error)
                dimeAvailable = false
            }
        }
    }
    
}

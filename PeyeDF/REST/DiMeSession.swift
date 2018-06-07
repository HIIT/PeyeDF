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

enum RESTError: Error {
    case invalidUrl
    case notFound
    /// We were asked to block the main thread, which is invalid.
    case waitOnMain
    /// Error otherwise undefined (check dime logs)
    case dimeError(String)
}

/// Contains configurations for the DiMe API using the native macOS URL Loading System
class DiMeSession {
    
    /// Is true if there is a connection to DiMe, and can be used
    private(set) static var dimeAvailable: Bool = false { didSet {
        NotificationCenter.default.post(name: PeyeConstants.diMeConnectionNotification, object: self, userInfo: ["available": dimeAvailable])
    } }
    
    /// Returns dime server url
    static var dimeUrl: String = {
        return UserDefaults.standard.object(forKey: PeyeConstants.prefDiMeServerURL) as! String
    }()
    
    /// Returns HTTP headers used for DiMe connection
    static var dimeHeaders: [String: String] { get {
        let user: String = UserDefaults.standard.object(forKey: PeyeConstants.prefDiMeServerUserName) as! String
        let password: String = UserDefaults.standard.object(forKey: PeyeConstants.prefDiMeServerPassword) as! String
        
        let credentialData = "\(user):\(password)".data(using: String.Encoding.utf8)!
        let base64Credentials = credentialData.base64EncodedString(options: [])
        
        return ["Authorization": "Basic \(base64Credentials)"]
    } }
    
    /// Shared url session used to push / fetch data
    fileprivate static var sharedSession: URLSession = URLSession(configuration: getConfiguration()) { willSet {
        sharedSession.finishTasksAndInvalidate()
    } }

    /// Updates the configuration (in case username and password change, for example)
    static func getConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = DiMeSession.dimeHeaders
        configuration.timeoutIntervalForRequest = 4 // seconds
        configuration.timeoutIntervalForResource = 4
        return configuration
    }
    
    /// Fetches a given URL using dime and calls back the given function with a json (if successful).
    /// Calls back with an error, if an error was given.
    static func fetch(urlString: String, callback: @escaping (JSON?, Error?) -> Void) {
        guard let url = URL(string: urlString) else {
            callback(nil, RESTError.invalidUrl)
            return
        }
        DiMeSession.sharedSession.dataTask(with: url) {
            data, response, error in
            if let data = data, error == nil {
                callback(try? JSON(data: data), nil)
            } else if let error = error {
                callback(nil, error)
            } else {
                callback(nil, nil)
            }
        }.resume()
    }
    
    /// Fetches a given URL using dime and calls back the given function with a json (if successful).
    /// Calls back with an error, if an error was given.
    /// - Attention: Do not call from main thread
    static func fetch_sync(urlString: String) -> (json: JSON?, error: Error?) {
        
        guard !Thread.isMainThread else {
            if #available(OSX 10.12, *) {
                os_log("Called from main thread, exiting", type: .error)
            }
            return (nil, RESTError.waitOnMain)
        }
        
        guard let url = URL(string: urlString) else {
            return(nil, RESTError.invalidUrl)
        }
        
        var retVal: (JSON?, Error?) = (nil, nil)
        let dGroup = DispatchGroup()
        
        dGroup.enter()
        DiMeSession.sharedSession.dataTask(with: url) {
            data, response, error in
            if let data = data, error == nil {
                retVal = (try? JSON(data: data), nil)
            } else if let error = error {
                retVal = (nil, error)
            } else {
                retVal = (nil, nil)
            }
            dGroup.leave()
        }.resume()
        
        if dGroup.wait(timeout: DispatchTime.now() + 10.0) == .timedOut {
            if #available(OSX 10.12, *) {
                os_log("Synchronous request fetch timeout", type: .fault)
            }
        }
        
        return retVal
    }

    /// Pushes a given dictionary (representing a json entry) to dime.
    /// Calls back the callback with the response from dime (which should mirror the pushed data).
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
            DiMeSession.sharedSession.dataTask(with: urlRequest) {
                data, _, error in
                if let error = error {
                    if #available(OSX 10.12, *) {
                        os_log("Error while uploading json: %@", type: .fault, error.localizedDescription)
                    }
                    callback(nil, error)
                } else if let data = data {
                    callback(try? JSON(data: data), nil)
                } else {
                    callback(nil, nil)
                }
            }.resume()
        } catch {
            if #available(OSX 10.12, *) {
                os_log("Failed to convert to json: %@", type: .error, error.localizedDescription)
            }
        }
    }
    
    /// **Synchronously** submits a delete http request for the given url.
    /// Returns a non-nil error in case operation didn't succeed.
    /// - Attention: do not call from the main thread.
    @discardableResult
    static func delete_sync(urlString: String) -> Error? {
        guard !Thread.isMainThread else {
            if #available(OSX 10.12, *) {
                os_log("Called from main thread, exiting", type: .error)
            }
            return RESTError.waitOnMain
        }

        guard let url = URL(string: urlString) else {
            return RESTError.invalidUrl
        }

        var urlRequest = URLRequest(url: url, timeoutInterval: 5.0)
        urlRequest.httpMethod = "DELETE"
        
        let dGroup = DispatchGroup()
        
        var returnedError: Error? = nil
        
        dGroup.enter()
        DiMeSession.sharedSession.dataTask(with: urlRequest) {
            _, response, error in
            if let foundError = error {
                returnedError = foundError
            } else {
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode != 204 {
                        returnedError = RESTError.dimeError("Code \(httpResponse.statusCode)")
                    }
                } else {
                    if #available(OSX 10.12, *) {
                        os_log("Failed to convert url response to http url response", type: .error)
                    }
                }
            }
            dGroup.leave()
        }.resume()
        
        if dGroup.wait(timeout: DispatchTime.now() + 10.0) == .timedOut {
            if #available(OSX 10.12, *) {
                os_log("Synchronous request fetch timeout", type: .fault)
            }
        }
        
        return returnedError
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
                var returnedError: Error? = nil
                // connection failed
                if let error = error {
                    if #available(OSX 10.12, *) {
                        os_log("Error while connecting to (pinging) DiMe. Error message: %@", type: .fault, error.localizedDescription)
                    }
                    returnedError = error
                } else if let jsonError = json?["error"].string {
                    if #available(OSX 10.12, *) {
                        os_log("DiMe Connection error: %@", type: .fault, jsonError)
                    }
                    returnedError = RESTError.dimeError(jsonError)
                } else {
                    if #available(OSX 10.12, *) {
                        os_log("Error while connecting to (pinging) DiMe. No error returned.", type: .fault)
                    }
                }
                callback?(false, returnedError)
                dimeAvailable = false
            }
        }
    }
    
}

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

/// This class is used to send data to dime, and to check the current connection to dime (it is useful to check
/// before sending anything).
class DiMePusher {

    /// Send the given data to dime
    /// - parameter callback: When done calls the callback where the first parameter is a boolean (true if successful) and
    /// the second the id of the returned item (nil if couldn't be found, or operation failed)
    static func sendToDiMe(_ dimeData: DiMeBase, callback: ((Bool, Int?) -> Void)? = nil) {
        guard DiMeSession.dimeAvailable else {
            callback?(false, nil)
            return
        }
       
        let endPoint: DiMeEndpoint
        switch dimeData {
        case is Event:
            endPoint = .Event
        case is DocumentInformationElement:
            endPoint = .InformationElement
        default:
            return
        }
        
        do {
            // attempt to translate json
            let options = JSONSerialization.WritingOptions.prettyPrinted
            
            try JSONSerialization.data(withJSONObject: dimeData.getDict(), options: options)
            
            // assume json conversion was a success, hence send to dime
            let server_url = DiMeSession.dimeUrl
            DiMeSession.push(urlString: server_url + "/data/\(endPoint.rawValue)", jsonDict: dimeData.getDict()) {
                json, _ in
                if let json = json {
                    if let error = json["error"].string {
                        AppSingleton.log.error("DiMe reply to submission contains error:\n\(error)")
                        if let message = json["message"].string {
                            AppSingleton.log.error("DiMe's error message:\n\(message)")
                        }
                        callback?(false, nil)
                    } else {
                        // assume submission was a success, call callback (if any) with returned id
                        callback?(true, json["id"].int)
                    }
                }
            }
        } catch {
            AppSingleton.log.error("Error while serializing json - no data sent:\n\(error)")
            callback?(false, nil)
        }
            
    }

}

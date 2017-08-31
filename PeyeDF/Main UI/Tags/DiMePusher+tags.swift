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
import os.log

extension DiMePusher {
    
    /// Add / remove a tag associated to a scientific document (which is an information element. Only information
    /// elements tag operations are supported.
    /// Calls the given callback with the updated list of tags from dime, nil if the operation failed.
    static func editTag(_ action: TagAction, tag: Tag, forId: Int, callback: (([Tag]?) -> Void)? = nil) {
        guard DiMeSession.dimeAvailable else {
            return
        }
        
        do {
            // attempt to translate json
            let options = JSONSerialization.WritingOptions.prettyPrinted
            
            try JSONSerialization.data(withJSONObject: tag.getDict(), options: options)
            let endpoint = DiMeEndpoint.InformationElement
            
            // assume json conversion was a success, hence send to dime
            let server_url = DiMeSession.dimeUrl
            
            DiMeSession.push(urlString: server_url + "/data/\(endpoint.rawValue)/\(forId)/\(action.rawValue)", jsonDict: tag.getDict()) {
                json, _ in
                if let json = json {
                    if let error = json["error"].string {
                        if #available(OSX 10.12, *) {
                            os_log("DiMe reply to submission contains error: %@", type: .error, error)
                        }
                        if let message = json["message"].string {
                            if #available(OSX 10.12, *) {
                                os_log("DiMe's error message: %@", type: .error, message)
                            }
                        }
                        callback?(nil)
                    } else {
                        let infoElem = DocumentInformationElement(fromDime: json)
                        callback?(infoElem.tags)
                    }
                }
            }
        } catch {
            if #available(OSX 10.12, *) {
                os_log("Error while serializing json - no data sent: %@", type: .error, error.localizedDescription)
            }
            callback?(nil)
        }
    }
    
}

enum TagAction: String {
    case Add = "addtag"
    case Remove = "removetag"
}

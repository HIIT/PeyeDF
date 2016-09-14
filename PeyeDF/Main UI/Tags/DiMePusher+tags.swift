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
import Alamofire

extension DiMePusher {
    
    /// Add / remove a tag associated to a scientific document (which is an information element. Only information
    /// elements tag operations are supported.
    /// Calls the given callback with the updated list of tags from dime, nil if the operation failed.
    static func editTag(_ action: TagAction, tag: Tag, forId: Int, callback: (([Tag]?) -> Void)? = nil) {
        guard dimeAvailable else {
            return
        }
        
        do {
            // attempt to translate json
            let options = JSONSerialization.WritingOptions.prettyPrinted
            
            try JSONSerialization.data(withJSONObject: tag.getDict(), options: options)
            let endpoint = DiMeEndpoint.InformationElement
            
            // assume json conversion was a success, hence send to dime
            let server_url = AppSingleton.dimeUrl
            
            AppSingleton.dimefire.request(server_url + "/data/\(endpoint.rawValue)/\(forId)/\(action.rawValue)", method: .post, parameters: tag.getDict(), encoding: JSONEncoding.default).responseJSON {
                response in
                if response.result.isFailure {
                    AppSingleton.log.error("Error while reading json response from DiMe: \(response.result.error)")
                    callback?(nil)
                } else {
                    let json = JSON(response.result.value!)
                    if let error = json["error"].string {
                        AppSingleton.log.error("DiMe reply to submission contains error:\n\(error)")
                        if let message = json["message"].string {
                            AppSingleton.log.error("DiMe's error message:\n\(message)")
                        }
                        callback?(nil)
                    } else {
                        let infoElem = DocumentInformationElement(fromDime: json)
                        callback?(infoElem.tags)
                    }
                }
            }
        } catch {
            AppSingleton.log.error("Error while serializing json - no data sent:\n\(error)")
            callback?(nil)
        }
    }
    
}

enum TagAction: String {
    case Add = "addtag"
    case Remove = "removetag"
}
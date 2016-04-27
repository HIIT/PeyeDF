//
//  File.swift
//  PeyeDF
//
//  Created by Marco Filetti on 22/04/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation
import Alamofire

extension HistoryManager {
    
    /// Add / remove a tag associated to a scientific document (which is an information element. Only information
    /// elements tag operations are supported.
    /// Calls the given callback with the updated list of tags from dime, nil if the operation failed.
    func editTag(action: TagAction, tag: Tag, forId: Int, callback: ([Tag]? -> Void)? = nil) {
        guard dimeAvailable else {
            return
        }
        
        do {
            // attempt to translate json
            let options = NSJSONWritingOptions.PrettyPrinted
            
            try NSJSONSerialization.dataWithJSONObject(tag.getDict(), options: options)
            let endpoint = DiMeEndpoint.InformationElement
            
            // assume json conversion was a success, hence send to dime
            let server_url = AppSingleton.dimeUrl
            
            AppSingleton.dimefire.request(Alamofire.Method.POST, server_url + "/data/\(endpoint.rawValue)/\(forId)/\(action.rawValue)", parameters: tag.getDict(), encoding: Alamofire.ParameterEncoding.JSON).responseJSON {
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

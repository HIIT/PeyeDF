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
    func editTag(action: TagAction, tagText: String, forId: String) {
        guard dimeAvailable else {
            return
        }
        
        let tag = Tag(withText: tagText)
        
        do {
            // attempt to translate json
            let options = NSJSONWritingOptions.PrettyPrinted
            
            try NSJSONSerialization.dataWithJSONObject(tag.getDict(), options: options)
            /* MF: Data + debug
            let outData = try NSJSONSerialization.dataWithJSONObject(dimeData.getDict(), options: options)
            let outString = String(data: outData, encoding: NSUTF8StringEncoding)
            if let outURL = outString?.dumpToTemp("toDime") {
                AppSingleton.log.debug("\(outURL.path!) dumped")
            } else {
                AppSingleton.log.error("Failed to write dump")
            }
            **/
            let endpoint = DiMeEndpoint.InformationElement
            
            // assume json conversion was a success, hence send to dime
            let server_url = AppSingleton.dimeUrl
            let headers = AppSingleton.dimeHeaders()
            
            Alamofire.request(Alamofire.Method.POST, server_url + "/data/\(endpoint)/\(forId)/\(action)", parameters: tag.getDict(), encoding: Alamofire.ParameterEncoding.JSON, headers: headers).responseJSON {
                response in
                if response.result.isFailure {
                    AppSingleton.log.error("Error while reading json response from DiMe: \(response.result.error)")
                } else {
                    let json = JSON(response.result.value!)
                    if let error = json["error"].string {
                        AppSingleton.log.error("DiMe reply to submission contains error:\n\(error)")
                        if let message = json["message"].string {
                            AppSingleton.log.error("DiMe's error message:\n\(message)")
                        }
                    }
                }
            }
        } catch {
            AppSingleton.log.error("Error while serializing json - no data sent:\n\(error)")
        }
    }
    
}

enum TagAction: String {
    case Add = "addtag"
    case Remove = "removetag"
}
//
//  CrossRefSession.swift
//  PeyeDF
//
//  Created by Marco Filetti on 19/09/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation

class CrossRefSession {
    fileprivate static let urlSession = URLSession(configuration: .default)
    
    /// Fetches metedata for a given doi using CrossRef, and calls a callback with the result
    /// (nil if failed)
    static func fetch(doi: String, callback: @escaping (JSON?) -> Void) {
        guard let url = URL(string: "http://api.crossref.org/works/\(doi)") else {
            AppSingleton.log.error("Error while creating crossref url")
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
                AppSingleton.log.error("Failed to fetch crossref data for \(doi): \(error)")
            }
        }.resume()
    }
}

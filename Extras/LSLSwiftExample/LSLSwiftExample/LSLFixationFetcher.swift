//
//  LSLFixationFetcher.swift
//  LSLSwiftExample
//
//  Created by Marco Filetti on 03/11/2016.
//  Copyright © 2016 Aalto University. All rights reserved.
//

import Foundation

class LSLFixationFetcher: LSLFetcher {
    
    private(set) var streamName: NSString = "<NOT SET>"
    
    var active: Bool = false
    
    typealias EyeDataType = FixationEvent
    
    let dataCallback: (EyeDataType?) -> Void
    
    init(name: String, dataCallback: @escaping (EyeDataType?) -> Void) {
        self.streamName = name as NSString
        self.dataCallback = dataCallback
    }

}

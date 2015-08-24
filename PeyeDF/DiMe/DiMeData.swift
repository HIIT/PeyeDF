//
//  DiMeData.swift
//  PeyeDF
//
//  Created by Marco Filetti on 24/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

/// UNUSED YET!
protocol DiMeData {
    var id: NSString {get}
    /// Unix time: ms since 1/1/70, UTC
    var timeCreated: Int {get}
}
//
//  InformationElement.swift
//  PeyeDF
//
//  Created by Marco Filetti on 24/08/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation

struct InformationElement: Equatable {
    /// Path on file or web
    var uri: String
}

func == (lhs: InformationElement, rhs: InformationElement) -> Bool {
    return (lhs.uri == rhs.uri)
}
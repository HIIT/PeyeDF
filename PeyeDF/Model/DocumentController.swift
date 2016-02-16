//
//  DocumentController.swift
//  PeyeDF
//
//  Created by Marco Filetti on 16/02/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation
import Cocoa

class DocumentController: NSDocumentController {
    
    override var hasEditedDocuments: Bool { get {
        return true
        }
    }
    
}
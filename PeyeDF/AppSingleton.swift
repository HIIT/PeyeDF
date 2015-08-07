//
//  AppSingleton.swift
//  PeyeDF
//
//  Created by Marco Filetti on 23/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

import Foundation
import Cocoa
import Quartz

/// Used to share states across the whole application, including posting history notifications to store. Contains:
///
/// - debugData: used to store and update debugging information
/// - debugWinInfo: window controller and debug controller for debug info window
/// - storyboard: the "Main" storyboard
class AppSingleton {
    static let storyboard = NSStoryboard(name: "Main", bundle: nil)!
}
//
//  DiMeEraser.swift
//  PeyeDF
//
//  Created by Marco Filetti on 28/09/2016.
//  Copyright © 2016 HIIT. All rights reserved.
//

import Foundation


/// Wraps delete operations
class DiMeEraser {
    
    /// Progress so far in deleting all orphaned events (ReadingEvents which do
    /// not have an associated ReadingEvent).
    /// Since there is only one bulk delete operation (orphaned deletion)
    /// we can use a constants here.
    static let orphanedDeleteProgress = Progress()
    
    func delbulk() {
        
        /// all session ids which have been already searched to dime
        /// if an id is here but not in the orphaned set, it is known not to be orphaned
        var processedSessionIds = Set<String>()
        
        /// all session ids for which we know do not have an associated summary event
        /// if an id is here, all associated readingevents should be deleted
        var orphanedSessionIds = Set<String>()
        
        
    }
    
}

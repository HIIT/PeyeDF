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
    
    /// **Synchronously Delete all summary and normal reading events which are associated to the given sessionId.
    /// - Attention: do not call from the main thread.
    static func deleteAllEvents(relatedToSessionId sessionId: String) {
        
        // Delete summaries with that session id
        (DiMeFetcher.getPeyeDFEvents(getSummaries: true, sessionId: sessionId) as? [SummaryReadingEvent])?.forEach() {
            if let id = $0.id {
                DiMeEraser.deleteEvent(id: id)
            }
        }
        
        // delete normal events with that session id
        DiMeFetcher.getPeyeDFEvents(getSummaries: true, sessionId: sessionId)?.forEach() {
            if let id = $0.id {
                DiMeEraser.deleteEvent(id: id)
            }
        }

    }
    
    /// **Synchronously** deletes a given event.
    /// - Attention: do not call from the main thread.
    static func deleteEvent(id: Int) {
        let urlString = DiMeSession.dimeUrl + "/data/event/\(id)"
        if let error = DiMeSession.delete_sync(urlString: urlString) {
            AppSingleton.log.debug("Found error: \(error)")
        }
    }
    
}

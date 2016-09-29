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
    
    /// Returns a progress that can be used to track the operation (which will be
    /// done asynchronously on the main utility queue).
    /// Calls the given callback on complete.
    static func deleteAllOrphaned(callback: ((Void) -> Void)? ) -> Progress {
        
        let orphanedDeleteProgress = Progress(totalUnitCount: .max)
        
        /// all session ids which have been already searched to dime
        /// if an id is here, it should not be searched for again.
        var processedSessionIds = Set<String>()
        
        DispatchQueue.global(qos: .utility).async {
            guard let allEvents = DiMeFetcher.getPeyeDFEvents(getSummaries: false) else {
                callback?()
                return
            }
            
            var orphanedSessionsFound = 0
            
            DispatchQueue.main.async {
                orphanedDeleteProgress.totalUnitCount = Int64(allEvents.count)
            }
            
            for event in allEvents {
                
                // if no summary events are found for this session id
                if !processedSessionIds.contains(event.sessionId) &&
                    DiMeFetcher.getPeyeDFEvents(getSummaries: true, sessionId: event.sessionId)?.count ?? 0 == 0 {
                    
                    deleteAllEvents(relatedToSessionId: event.sessionId)
                    processedSessionIds.insert(event.sessionId)
                    orphanedSessionsFound += 1
                    AppSingleton.log.debug("Deleting for sesId: \(event.sessionId)")
                }
                
                DispatchQueue.main.async {
                    orphanedDeleteProgress.completedUnitCount += 1
                }

            }
            
            AppSingleton.log.debug("Deleted \(orphanedSessionsFound) orphaned sessions")
            callback?()
        }
        
        return orphanedDeleteProgress
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
        DiMeFetcher.getPeyeDFEvents(getSummaries: false, sessionId: sessionId)?.forEach() {
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

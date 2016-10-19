//
// Copyright (c) 2015 Aalto University
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

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

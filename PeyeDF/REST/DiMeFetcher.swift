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

/// Instances that want to receive dime data must implement this protocol and add themselves as delegates to the DiMeFetcher
protocol DiMeReceiverDelegate: class {
    
    /// Receive all summaries information elements and associated informatione elements in a tuple. Nil means nothing was found. Receving this signals that the fetching operation is finished.
    func receiveAllSummaries(_ tuples: [(ev: SummaryReadingEvent, ie: ScientificDocument?)]?)
    
    /// Indicates that the fetching operation started / isprogessing, by communicating how many items have been received and how many are missing.
    func updateProgress(_ received: Int, total: Int)
}

/// DiMeFetcher is supposed to be used as a singleton (via sharedFetcher)
class DiMeFetcher {
    
    /// Receiver of dime info. Delegate method will be called once fetching finishes.
    fileprivate let receiver: DiMeReceiverDelegate
    
    /// How many info elements still have to be fetched. When this number reaches 0, the delegate is called.
    fileprivate var missingInfoElems = Int.max
    
    /// Outgoing summary reading events and associate info elements
    fileprivate var outgoingSummaries = [(ev: SummaryReadingEvent, ie: ScientificDocument?)]()
    
    init(receiver: DiMeReceiverDelegate) {
        self.receiver = receiver
    }
    
    // MARK: - Instance methods
    
    /// Retrieves **all** summary information elements from dime and later sends outgoingSummaries to the receiver via fetchSummaryEvents.
    func getSummaries() {
        fetchPeyeDFEvents(getSummaries: true, sessionId: nil, callback: fetchSummaryEvents)
    }
    
    /// Retrieves all non-summary reading events with the given sessionId and callbacks the given function using the
    /// result as a parameter.
    func getNonSummaries(withSessionId sessionId: String, callbackOnComplete: @escaping (([ReadingEvent]) -> Void)) {
        fetchPeyeDFEvents(getSummaries: false, sessionId: sessionId) {
            json in
            var foundEvents = [ReadingEvent]()
            
            for elem in json.arrayValue {
                let readingEvent = ReadingEvent(fromDime: elem)
                if readingEvent.sessionId == sessionId {
                    foundEvents.append(readingEvent)
                }
            }
            
            callbackOnComplete(foundEvents)
        }
    }
    
    /// Attempt to retrieve a scientific document for a given **sessionId**.
    /// Useful to check to which document any event (NonSummary) was associated to.
    /// Asynchronously calls the given callback with the obtained scidoc.
    func retrieveScientificDocument(forSessionId sesId: String, callback: @escaping (ScientificDocument?) -> Void) {
        getNonSummaries(withSessionId: sesId) {
            events in
            if events.count == 0 {
                callback(nil)
                AppSingleton.log.warning("Didn't find any event with sessionId: \(sesId)")
            } else {
                DiMeFetcher.retrieveScientificDocument(events.last!.infoElemId as String) {
                    sciDoc in
                    callback(sciDoc)
                }
            }
        }
    }
    
    /// **Synchronously** attempt to retrieve a single summary event for the given sessionId.
    /// Returns a tuple containing reading event and scidoc or nil if it failed.
    /// - Attention: Don't call this from the main thread.
    func getTuple(forSessionId sesId: String) -> (ev: SummaryReadingEvent, ie: ScientificDocument)? {
        
        var foundEvent: SummaryReadingEvent?
        var foundDoc: ScientificDocument?
        
        let dGroup = DispatchGroup()
        
        dGroup.enter()
        fetchPeyeDFEvents(getSummaries: true, sessionId: sesId) {
            json in
            guard let retVals = json.array , retVals.count > 0 else {
                AppSingleton.log.error("Failed to find results for sessionId \(sesId)")
                dGroup.leave()
                return
            }
            if retVals.count != 1 {
                AppSingleton.log.warning("Found \(retVals.count) instead of 1 for sessionId \(sesId). Returning last one.")
            }
            foundEvent = SummaryReadingEvent(fromDime: retVals.last!)
            
            guard foundEvent!.infoElemId != "" else {
                AppSingleton.log.error("Found an event but no associated infoElemId for sessionId \(sesId)")
                dGroup.leave()
                return
            }
            
            DiMeFetcher.retrieveScientificDocument(foundEvent!.infoElemId as String) {
                fetchedDoc in
                guard let sciDoc = fetchedDoc else {
                    AppSingleton.log.error("Failed to find SciDoc for sessionId \(sesId)")
                    dGroup.leave()
                    return
                }
                // success
                foundDoc = sciDoc
                dGroup.leave()
            }
        }
        
        // wait 5 seconds for all operations to complete
        let waitTime = DispatchTime.now() + Double(Int64(5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        
        if dGroup.wait(timeout: waitTime) == .timedOut {
            AppSingleton.log.debug("Tuple request failed")
        }
        
        guard let ev = foundEvent, let ie = foundDoc else {
            return nil
        }
        return (ev: ev, ie: ie)
    }
    
    // MARK: - Static methods
    
    /// Asynchronously attempt to retrieve a list of tags for a given information element (using appId).
    /// Calls the callback with a list of tags (empty if none) or nil if it failed.
    static func retrieveTags(forAppId appId: String, callback: @escaping ([Tag]?) -> Void) {
        
        let server_url = DiMeSession.dimeUrl
        
        let reqString = server_url + "/data/informationelements?appId=" + appId
        
        DiMeSession.fetch(urlString: reqString) {
            json, _ in
            if let json = json {
                // assume first returned item is the one we are looking for
                let firstResponse = json[0]
                if let error = firstResponse["error"].string {
                    AppSingleton.log.error("Dime fetched json contains error:\n\(error)")
                }
                if let appId = firstResponse["appId"].string {
                    if appId == appId {
                        // success
                        let newInfoElem = DocumentInformationElement(fromDime: firstResponse)
                        callback(newInfoElem.tags)
                    } else {
                        AppSingleton.log.error("Retrieved info element id does not match requested id: \(json)")
                        callback(nil)
                    }
                } else {
                    AppSingleton.log.warning("Info element with appId:'\(appId)' was not found in the database.")
                    callback(nil)
                }
            }
        }
    }
    
    /// **Synchronously** attempt to retrieve a single information element for the given contentHash.
    /// Returns a scientific document or nil if it failed.
    /// - Attention: Don't call this from the main thread.
    static func getScientificDocument(contentHash hash: String) -> ScientificDocument? {
        
        var foundDoc: ScientificDocument?
        
        let dGroup = DispatchGroup()
        
        let server_url = DiMeSession.dimeUrl
        
        let reqString = server_url + "/data/informationelements?contentHash=" + hash
        
        dGroup.enter()
        DiMeSession.fetch(urlString: reqString) {
            json, _ in
            if let json = json {
                // assume first returned item is the one we are looking for
                let firstResponse = json[0]
                if let error = firstResponse["error"].string {
                    AppSingleton.log.error("Dime fetched json contains error:\n\(error)")
                }
                if let contentHash = firstResponse["contentHash"].string {
                    if hash == contentHash {
                        // success
                        foundDoc = ScientificDocument(fromDime: firstResponse)
                    } else {
                        AppSingleton.log.error("Retrieved contentHash does not match requested contentHash: \(json)")
                    }
                } else {
                    AppSingleton.log.debug("Info element with contentHash:'\(hash)' was not found in the database.")
                }
            }
            dGroup.leave()
        }
        
        // wait 5 seconds for operation to complete
        let waitTime = DispatchTime.now() + Double(Int64(5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        
        if dGroup.wait(timeout: waitTime) == DispatchTimeoutResult.timedOut {
            AppSingleton.log.debug("SciDoc request timed out")
        }
        
        return foundDoc
    }
    
    /// Attempt to retrieve a single ScientificDocument from a given info element app id.
    /// Asynchronously calls the given callback function once retrieval is complete.
    /// Called-back function will contain nil if retrieval failed.
    static func retrieveScientificDocument(_ appId: String, callback: @escaping (ScientificDocument?) -> Void) {
        
        let reqString = DiMeSession.dimeUrl + "/data/informationelements?appId=" + appId
        
        DiMeSession.fetch(urlString: reqString) {
            json, _ in
            if let json = json {
                // assume first returned item is the one we are looking for
                let firstResponse = json[0]
                if let error = firstResponse["error"].string {
                    AppSingleton.log.error("Dime fetched json contains error:\n\(error)")
                }
                if let appId = firstResponse["appId"].string {
                    if appId == appId {
                        // success
                        let newScidoc = ScientificDocument(fromDime: firstResponse)
                        callback(newScidoc)
                    } else {
                        AppSingleton.log.error("Retrieved info element id does not match requested id: \(json)")
                        callback(nil)
                    }
                } else {
                    AppSingleton.log.debug("Info element with appId:'\(appId)' was not found in the database.")
                    callback(nil)
                }
            }
        }
    }
    
    /// Attempts to convert a contenthash to a URL pointing to a file on disk.
    /// Returns nil if the contenthash was not on dime, or if the url points to an non-existing file.
    /// Aysnchronously calls the specified callback with the (nullable) url.
    static func retrieveUrl(forContentHash cHash: String, callback: @escaping (URL?) -> Void ) {
        // run task on default concurrent queue
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            
            guard let sciDoc = DiMeFetcher.getScientificDocument(contentHash: cHash) else {
                callback(nil)
                return
            }
            
            if FileManager.default.fileExists(atPath: sciDoc.uri) {
                callback(URL(fileURLWithPath: sciDoc.uri))
            } else {
                callback(nil)
            }
            
        }
    }
    
    // MARK: - Private methods
    
    /// Retrieves PeyeDF Reading events and calls the specified function once retrieval is complete.
    /// - parameter getSummaries: Set to true to get summary reading events, false for non-summary
    /// - parameter sessionId: If not-nil, retrieves only elements with the given sessionId
    ///                        using dime filtering. Set to nil to get all events.
    fileprivate func fetchPeyeDFEvents(getSummaries: Bool, sessionId: String?, callback: @escaping (JSON) -> Void) {
        let server_url = DiMeSession.dimeUrl
        
        var filterString = ""
        if sessionId != nil {
            filterString = "&sessionId=\(sessionId!)"
        }
        
        var typeString = "<UNSET>"
        if getSummaries {
            typeString = "SummaryReadingEvent"
        } else {
            typeString = "ReadingEvent"
        }
        
        DiMeSession.fetch(urlString: server_url + "/data/events?actor=PeyeDF&type=http://www.hiit.fi/ontologies/dime/%23\(typeString)" + filterString) {
            json, error in
            if let json = json {
                callback(json)
            } else {
                AppSingleton.log.error("Error fetching list of PeyeDF events: \(error)")
            }
        }
    }
   
    /// Puts all reading events which are summary in the outgoing tuple, and fetches scientific documents
    /// (aka information elements) associated to each summary event.
    /// Can be used as a callback function for fetchAllPeyeDFEvents(...)
    fileprivate func fetchSummaryEvents(_ json: JSON) {
        missingInfoElems = 0
        outgoingSummaries = [(ev: SummaryReadingEvent, ie: ScientificDocument?)]()
        for readingEvent in json.arrayValue {
            outgoingSummaries.append((ev: SummaryReadingEvent(fromDime: readingEvent), ie: nil))
            missingInfoElems += 1
        }
        // convert info element ids to scientific documents and add them to outgoing data
        var i = 0
        for tuple in outgoingSummaries {
            getScientificDocument(i, infoElemId: tuple.ev.infoElemId as String)
            i += 1
        }
        
        // if nothing is being sent, call receiveAllSummaries with nil
        if outgoingSummaries.count == 0 {
            self.receiver.receiveAllSummaries(nil)
        } else {
            self.receiver.updateProgress(outgoingSummaries.count - missingInfoElems, total: outgoingSummaries.count)
        }
    }
    
    /// Gets a scientific document for a given index (referring to the outgoing tuple) and puts it in the appropriate place
    fileprivate func getScientificDocument(_ forIndex: Int, infoElemId: String) {
        DiMeFetcher.retrieveScientificDocument(infoElemId) {
            newScidoc in
            
            self.outgoingSummaries[forIndex].ie = newScidoc
            self.missingInfoElems -= 1
            self.receiver.updateProgress(self.outgoingSummaries.count - self.missingInfoElems, total: self.outgoingSummaries.count)
            // all data has been fetched, send it
            if self.missingInfoElems == 0 {
                self.receiver.receiveAllSummaries(self.outgoingSummaries)
                }
            }
    }
    
}

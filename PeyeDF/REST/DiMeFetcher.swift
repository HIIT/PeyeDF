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

// MARK: - Enums

///

/// Points to an endpoint, with the associated string used in the url for the request
enum DiMeEndpoint: String {
    case Event = "event"
    case InformationElement = "informationelement"
}

/// Uses same tags as radio buttons used to select these (make sure this is reflected in IB)
enum DiMeSearchableItem: Int {
    case sciDoc
    case readingEvent
}

/// Can be either reading event or summary reading event. The raw value points
/// to the DiMe parameter query to only fetch that type.
enum EventTypeQuery: String {
    case ReadingEvent = "type=http://www.hiit.fi/ontologies/dime/%23ReadingEvent"
    case SummaryReadingEvent = "type=http://www.hiit.fi/ontologies/dime/%23SummaryReadingEvent"
}

/// Used to identify IDs which can be "converted" to a ScientificDocument
/// by querying DiMe using the DiMeFetcher class.
/// The String associated to each represents its respective id.
enum SciDocConvertible {
    /// The id used by DiMe (from 1 incremental) to store information elements (and hence Scientific Documents)
    case id(Int)
    /// The appId used by PeyeDF to identify a Scientific Document. This is normally
    /// PeyeDF_<contentHash>
    case appId(String)
    /// The sessionId which refers to an event which in turn refers to a Scientific Document
    case sessionId(String)
    /// The content hash used to identify a Scientific Document (hash of the plain text)
    case contentHash(String)
}


// MARK: - Protocols

/// Instances that want to receive dime data must implement this protocol and add themselves as delegates to the DiMeFetcher
protocol DiMeReceiverDelegate: class {
    
    /// Receive all summaries information elements and associated informatione elements in a tuple. Nil means nothing was found. Receving this signals that the fetching operation is finished.
    func receiveAllSummaries(_ tuples: [(ev: SummaryReadingEvent, ie: ScientificDocument)]?)
    
}

// MARK: - Main class

/// DiMeFetcher is supposed to be used as a singleton (via sharedFetcher)
class DiMeFetcher {
    
    /// Progress indicating amount of units to fetch vs units fetched
    let fetchProgress = Progress()
    
    /// Receiver of dime info. Delegate method will be called once fetching finishes.
    fileprivate let receiver: DiMeReceiverDelegate
    
    init(receiver: DiMeReceiverDelegate) {
        self.receiver = receiver
    }
    
    // MARK: - Instance methods
    
    /// Retrieves **all** summary information elements from dime and later sends them to the receiver via fetchSummaryEvents.
    func getAllSummaries() {
        // update progress so that it displays in ui
        DispatchQueue.main.async {
            self.fetchProgress.completedUnitCount = 0
            self.fetchProgress.totalUnitCount = Int64.max
        }
        DiMeFetcher.fetchPeyeDFEvents(getSummaries: true, callback: sendSummaryEvents)
    }
    
    /// Searches for whole documents (information elements) or seen text (reading events) containig the given text. Asynchronously lets the receiver know using the receiveAllSummaries method
    func getSummariesForSearch(string: String, inData: DiMeSearchableItem) {
        
        // update progress so that it displays in ui
        DispatchQueue.main.async {
            self.fetchProgress.completedUnitCount = 0
            self.fetchProgress.totalUnitCount = Int64.max
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            var foundSummaries = [(ev: SummaryReadingEvent, ie: ScientificDocument)]()
            switch inData {
            case .readingEvent:
                // reading event search: once we got the list of events that satisfy query,
                // use all their sessionIds to find all summary reading events that have those sessionIds
                let foundEvents = DiMeFetcher.searchReadingEvents(for: string)
                
                DispatchQueue.main.async {
                    self.fetchProgress.totalUnitCount = Int64(foundEvents?.count ?? 0)
                }
                
                var processedSessionIds = Set<String>()
                
                foundEvents?.forEach() {
                    if !processedSessionIds.contains($0.sessionId) {
                        
                        let scidoc = $0.targettedResource
                        let summaryEvents = DiMeFetcher.getPeyeDFEvents(getSummaries: true, sessionId: $0.sessionId, elemId: scidoc!.id)
                        summaryEvents?.forEach() {
                            if let scidoc = scidoc {
                                foundSummaries.append((ev: $0, ie: scidoc))
                            }
                        }
                        
                        processedSessionIds.insert($0.sessionId)
                    }
                    // advance count for each element
                    DispatchQueue.main.async {
                        self.fetchProgress.completedUnitCount += 1
                    }
                }
                
                if foundSummaries.count > 0 {
                    self.receiver.receiveAllSummaries(foundSummaries)
                } else {
                    self.receiver.receiveAllSummaries(nil)
                }
                
            case .sciDoc:
                // document search: once we got the list of documents that satisfy query,
                // use their "id" field to get all summary events that have the same id
                let foundScidocs = DiMeFetcher.searchSciDocs(for: string)
                    
                DispatchQueue.main.async {
                    self.fetchProgress.totalUnitCount = Int64(foundScidocs?.count ?? 0)
                }
                
                var processedIds = Set<Int>()
                
                foundScidocs?.forEach() {
                    scidoc in
                    
                    if let id = scidoc.id, !processedIds.contains(id) {
                        let summaryEvents = DiMeFetcher.getPeyeDFEvents(getSummaries: true, elemId: id)
                        summaryEvents?.forEach() {foundSummaries.append((ev: $0, ie: scidoc))}
                        
                        processedIds.insert(id)
                    }
                    // advance count for each element
                    DispatchQueue.main.async {
                        self.fetchProgress.completedUnitCount += 1
                    }
                }
                
                if foundSummaries.count > 0 {
                    self.receiver.receiveAllSummaries(foundSummaries)
                } else {
                    self.receiver.receiveAllSummaries(nil)
                }
                    
            }
        }
    }
    
    /// Retrieves all non-summary reading events with the given sessionId and callbacks the given function using the
    /// result as a parameter.
    func retrieveNonSummaries(withSessionId sessionId: String, callbackOnComplete: @escaping (([ReadingEvent]) -> Void)) {
        DiMeFetcher.fetchPeyeDFEvents(getSummaries: false, sessionId: sessionId) {
            json in
            var foundEvents = [ReadingEvent]()
            
            for elem in (json?.arrayValue)! {
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
        retrieveNonSummaries(withSessionId: sesId) {
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
        
        guard !Thread.isMainThread else {
            AppSingleton.log.error("Attempted to call on the main thread, aborting")
            return nil
        }
        
        var foundEvent: SummaryReadingEvent?
        var foundDoc: ScientificDocument?
        
        let dGroup = DispatchGroup()
        
        dGroup.enter()
        DiMeFetcher.fetchPeyeDFEvents(getSummaries: true, sessionId: sesId) {
            json in
            guard let retVals = json?.array , retVals.count > 0 else {
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
        let waitTime = DispatchTime.now() + 5.0
        
        if dGroup.wait(timeout: waitTime) == .timedOut {
            AppSingleton.log.debug("Tuple request failed")
        }
        
        guard let ev = foundEvent, let ie = foundDoc else {
            return nil
        }
        return (ev: ev, ie: ie)
    }
    
    // MARK: - Static methods
    
    /// Asynchronously retrieves PeyeDF Reading events and calls the specified function once retrieval is complete.
    /// - parameter getSummaries: Set to true to get summary reading events, false for non-summary
    /// - parameter sessionId: If given, retrieves only elements with the given sessionId
    ///                        using dime filtering. Set to nil to get all events.
    /// - parameter elemId: If given, only retrieves elements associated to InformationElements
    ///                     which have this id (integer id, not appId)
    static func fetchPeyeDFEvents(getSummaries: Bool, sessionId: String? = nil, elemId: Int? = nil, callback: @escaping (JSON?) -> Void) {
        let server_url = DiMeSession.dimeUrl
        
        var filterString = ""
        
        // append optional query parameters as our filters
        if sessionId != nil {
            filterString += "&sessionId=\(sessionId!)"
        }
        if elemId != nil {
            filterString += "&elemId=\(elemId!)"
        }
        
        let typeQuery: EventTypeQuery
        if getSummaries {
            typeQuery = .SummaryReadingEvent
        } else {
            typeQuery = .ReadingEvent
        }
        
        DiMeSession.fetch(urlString: server_url + "/data/events?actor=PeyeDF&\(typeQuery.rawValue)" + filterString) {
            json, error in
            if let json = json {
                callback(json)
            } else {
                AppSingleton.log.error("Error fetching list of PeyeDF events: \(error)")
                callback(nil)
            }
        }
    }
    
    /// **Synchronously** attempt to retrieve reading events satisfying the given parameters.
    /// - parameter getSummaries: Set to true to get summary reading events, false for non-summary
    /// - parameter sessionId: If given, retrieves only elements with the given sessionId
    ///                        using dime filtering. Set to nil to get all events.
    /// - parameter elemId: If given, only retrieves elements associated to InformationElements
    ///                     which have this id (integer id, not appId)
    /// - Attention: Don't call this from the main thread.
    static func getPeyeDFEvents(getSummaries: Bool, sessionId: String? = nil, elemId: Int? = nil) -> [SummaryReadingEvent]? {
        
        let server_url = DiMeSession.dimeUrl
        
        var filterString = ""
        
        // append optional query parameters as our filters
        if sessionId != nil {
            filterString += "&sessionId=\(sessionId!)"
        }
        if elemId != nil {
            filterString += "&elemId=\(elemId!)"
        }
        
        let typeQuery: EventTypeQuery
        if getSummaries {
            typeQuery = .SummaryReadingEvent
        } else {
            typeQuery = .ReadingEvent
        }
        
        let (json, _) = DiMeSession.fetch_sync(urlString: server_url + "/data/events?actor=PeyeDF&\(typeQuery.rawValue)" + filterString)
        if let retrievedEvents = json?.array {
            return retrievedEvents.map({SummaryReadingEvent(fromDime: $0)})
        } else {
            return nil
        }
    }

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
    
    /// **Synchronously** attempt to retrieve a single information element for the given id.
    /// The id can be any id defined by SciDocConvertible (appId, int id, etc.)
    /// Returns a scientific document or nil if it failed.
    /// - Attention: Don't call this from the main thread.
    static func getScientificDocument(for idType: SciDocConvertible, reportErrors: Bool = true) -> ScientificDocument? {
        
        /// Helper function to synchronously fetch a scientific document given a url, logging any error.
        func getSciDocFromDime(urlString: String, reportErrors: Bool) -> ScientificDocument? {
            let (responseJson, _) = DiMeSession.fetch_sync(urlString: urlString)
            guard let json = responseJson, json.count > 0 else {
                if reportErrors {
                    AppSingleton.log.debug("ScientificDocument for request:'\(urlString)' was not found in the database.")
                }
                return nil
            }
            // assume last returned item is the one we are looking for
            let lastResponse = json[json.count - 1]
            if let error = lastResponse["error"].string {
                if reportErrors {
                    AppSingleton.log.error("Dime fetched json contains error:\n\(error)")
                }
                return nil
            }
            let foundScidoc = ScientificDocument(fromDime: lastResponse)
            if foundScidoc.appId == "" || foundScidoc.contentHash == nil {
                if reportErrors {
                    AppSingleton.log.error("Found Scientific Document appears invalid (no IDs)")
                }
                return nil
            } else {
                return foundScidoc
            }
        }
        
        guard !Thread.isMainThread else {
            AppSingleton.log.error("Attempted to call on the main thread, aborting")
            return nil
        }
        
        // format: api/data/informationelement<suffix><value>
        
        let endpoint: DiMeEndpoint
        let querySuffix: String
        let queryValue: String
        
        switch(idType) {
        case .appId(let appId):
            // api/data/informationelements/?appId=<appId>
            endpoint = .InformationElement
            querySuffix = "s/?appId="
            queryValue = appId
        case .contentHash(let cHash):
            // api/data/informationelements/?contentHash=<appId>
            endpoint = .InformationElement
            querySuffix = "s/?contentHash="
            queryValue = cHash
        case .id(let id):
            // api/data/informationelement/<id>
            endpoint = .InformationElement
            querySuffix = "/"
            queryValue = "\(id)"
        case .sessionId(let sessionId):
            // api/data/events/?sessionId=<sessionId>
            endpoint = .Event
            querySuffix = "s/?sessionId="
            queryValue = sessionId
        }
        
        let query_url = DiMeSession.dimeUrl + "/data/"
        
        switch idType {
        case .sessionId:
            // in case we are looking for a sessionId, first we try with summary events,
            // then if none we try with reading events
            if let foundSummaries = DiMeFetcher.getPeyeDFEvents(getSummaries: true, sessionId: queryValue),
                let lastSummary = foundSummaries.last,
                let targettedResource = lastSummary.targettedResource {
                return targettedResource
            } else if let foundEvents = DiMeFetcher.getPeyeDFEvents(getSummaries: true, sessionId: queryValue),
                let lastEvent = foundEvents.last,
                let targettedResource = lastEvent.targettedResource {
                return targettedResource
            } else  {
                if reportErrors {
                    AppSingleton.log.debug("Failed to find an associated document for sessionId:\(queryValue)")
                }
                return nil
            }
            
        default:
            // otherwise, just use the query to filter dime results (use helper function)
            return getSciDocFromDime(urlString: query_url + "\(endpoint.rawValue)\(querySuffix)\(queryValue)", reportErrors: reportErrors)
        }
        
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
    
    /// **Synchronously** search for the given string in reading events only (not summary reading events)
    static func searchReadingEvents(for searchQuery: String) -> [ReadingEvent]? {
        
        let searchType = EventTypeQuery.ReadingEvent
        
        let result = DiMeSession.fetch_sync(urlString: DiMeSession.dimeUrl + "/eventsearch?query=\(searchQuery)&\(searchType.rawValue)")
        
        guard let json = result.json, let docs = json["docs"].array, docs.count > 0 else {
            return nil
        }
        
        return docs.map({ReadingEvent(fromDime: $0)})

    }
    
    /// **Synchronously** search for the given string in scientific documents only
    static func searchSciDocs(for searchQuery: String) -> [ScientificDocument]? {
        
        let searchType = EventTypeQuery.SummaryReadingEvent
        
        let result = DiMeSession.fetch_sync(urlString: DiMeSession.dimeUrl + "/search?query=\(searchQuery)&\(searchType.rawValue)")
    
        guard let json = result.json, let docs = json["docs"].array, docs.count > 0 else {
            return nil
        }

        return docs.map({ScientificDocument(fromDime: $0)})
    
    }
    
    /// Attempts to convert any kind of ID string (see SciDocConvertible) to a URL pointing to a file on disk.
    /// Returns nil if the specified item was not on dime, or if the url points to an non-existing file.
    /// Aysnchronously calls the specified callback with the (nullable) url.
    static func retrieveUrl(for idType: SciDocConvertible, reportErrors: Bool = true, callback: @escaping (URL?) -> Void ) {
        // run task on default concurrent queue
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            
            guard let sciDoc = DiMeFetcher.getScientificDocument(for: idType, reportErrors: reportErrors) else {
                callback(nil)
                return
            }
            
            if FileManager.default.fileExists(atPath: sciDoc.uri) {
                callback(URL(fileURLWithPath: sciDoc.uri))
            } else {
                if reportErrors {
                    AppSingleton.log.warning("URL for associated SciDoc not found: \(sciDoc.uri)")
                }
                callback(nil)
            }
            
        }
    }
    
    /// Asynchronously fetch all ReadingRects associated to an information element id which have been added by the user (selection or quick mark)
    /// Returns an empty array, if operation fails or none are found
    static func retrieveAllManualReadingRects(forSciDoc: ScientificDocument, callback: @escaping ([ReadingRect]) -> Void) -> Void {
        
        guard let id = forSciDoc.id else {
            callback([])
            return
        }
        
        fetchPeyeDFEvents(getSummaries: true, elemId: id) {
            json in
            
            var foundRects = [ReadingRect]()  // this will be set to an array of count > 0 if successful
            
            // eventually call the callback, no matter what
            defer {
                callback(foundRects)
            }
            
            guard let retVals = json?.array , retVals.count > 0 else {
                return
            }
            
            let foundEvents: [SummaryReadingEvent] = retVals.map({SummaryReadingEvent(fromDime: $0)})
            foundEvents.forEach {
                foundRects.append(contentsOf: $0.pageRects.filter({$0.classSource == .click || $0.classSource == .manualSelection}))
            }
        }
        
    }
    
    // MARK: - Private methods
    
    /// Puts all reading events which are summary in the outgoing tuple, and fetches scientific documents
    /// (aka information elements) associated to each summary event.
    /// Sends the result to the receiver.
    /// Can be used as a callback function for fetchAllPeyeDFEvents(...)
    fileprivate func sendSummaryEvents(_ json: JSON?) {
        
        var outgoingSummaries = [(ev: SummaryReadingEvent, ie: ScientificDocument)]()
        
        guard let json = json else {
            AppSingleton.log.warning("Failed to obtain summary events")
            return
        }

        // Update amount of work to do on main queue (so it shows in UI)
        DispatchQueue.main.async {
            self.fetchProgress.totalUnitCount = Int64(json.array?.count ?? 0)
        }

        for jsonItem in json.arrayValue {
            let readingEvent = SummaryReadingEvent(fromDime: jsonItem)
            if let sciDoc = readingEvent.targettedResource {
                outgoingSummaries.append((ev: readingEvent, ie: sciDoc))
            }
            // update amount of work done (on main queue, so it shows on UI)
            DispatchQueue.main.async {
                self.fetchProgress.completedUnitCount += 1
            }
        }
        
        // if nothing is being sent, call receiveAllSummaries with nil
        if outgoingSummaries.count == 0 {
            self.receiver.receiveAllSummaries(nil)
        } else {
            self.receiver.receiveAllSummaries(outgoingSummaries)
        }
    }
    
}

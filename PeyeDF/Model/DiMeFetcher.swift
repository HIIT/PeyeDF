//
//  DiMeFetcher.swift
//  PeyeDF
//
//  Created by Marco Filetti on 03/11/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Foundation
import Alamofire

/// Instances that want to receive dime data must implement this protocol and add themselves as delegates to the DiMeFetcher
protocol DiMeReceiverDelegate: class {
    
    func receiveAllSummaries(tuples: [(ev: SummaryReadingEvent, ie: ScientificDocument?)])
}

/// DiMeFetcher is supposed to be used as a singleton (via sharedFetcher)
class DiMeFetcher {
    
    /// Receiver of dime info. Delegate method will be called once fetching finishes.
    private let receiver: DiMeReceiverDelegate
    
    /// How many info elements still have to be fetched. When this number reaches 0, the delegate is called.
    private var missingInfoElems = Int.max
    
    /// Outgoing summary reading events and associate info elements
    private var outgoingSummaries = [(ev: SummaryReadingEvent, ie: ScientificDocument?)]()
    
    init(receiver: DiMeReceiverDelegate) {
        self.receiver = receiver
    }
    
    /// Retrieves **all** summary information elements from dime and later sends outgoingSummaries to the receiver via fetchSummaryEvents.
    func getSummaries() {
        fetchPeyeDFEvents(getSummaries: true, sessionId: nil, callback: fetchSummaryEvents)
    }
    
    /// Retrieves all non-summary reading events with the given sessionId and callbacks the given function using the
    /// result as a parameter.
    func getNonSummaries(withSessionId sessionId: String, callbackOnComplete: ([ReadingEvent] -> Void)) {
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
    
    /// Attempt to retrieve a single ScientificDocument from a given info element id.
    /// **Asynchronously** calls the given callback function once retrieval is complete.
    /// Called-back function will contain nil if retrieval failed.
    static func retrieveScientificDocument(infoElemId: String, callback: (ScientificDocument?) -> Void) {
        
        let server_url = AppSingleton.dimeUrl
        let headers = AppSingleton.dimeHeaders
        
        let reqString = server_url + "/data/informationelements?appId=" + infoElemId
        
        Alamofire.request(.GET, reqString, headers: headers).responseJSON() {
            response in
            if response.result.isFailure {
                AppSingleton.log.error("Error fetching information element: \(response.result.error!)")
                callback(nil)
            } else {
                // assume first returned item is the one we are looking for
                let json = JSON(response.result.value!)[0]
                if let error = json["error"].string {
                    AppSingleton.log.error("Dime fetched json contains error:\n\(error)")
                }
                if let appId = json["appId"].string {
                    if appId == infoElemId {
                        let newScidoc = ScientificDocument(fromJson: json)
                        callback(newScidoc)
                    } else {
                        AppSingleton.log.error("Retrieved info element id does not match requested id: \(response.result.value!)")
                        callback(nil)
                    }
                } else {
                    AppSingleton.log.debug("Failed to retrieve a valid info element: \(response.result.value!)")
                    callback(nil)
                }
            }
        }
    }
    
    /// Retrieves PeyeDF Reading events and calls the specified function once retrieval is complete.
    /// - parameter getSummaries: Set to true to get summary reading events, false for non-summary
    /// - parameter sessionId: If not-nil, retrieves only elements with the given sessionId
    ///                        using dime filtering. Set to nil to get all events.
    private func fetchPeyeDFEvents(getSummaries getSummaries: Bool, sessionId: String?, callback: (JSON) -> Void) {
        let server_url = AppSingleton.dimeUrl
        let headers = AppSingleton.dimeHeaders
        
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
        
        Alamofire.request(.GET, server_url + "/data/events?actor=PeyeDF&type=http://www.hiit.fi/ontologies/dime/%23\(typeString)" + filterString, headers: headers).responseJSON() {
            response in
            if response.result.isFailure {
                AppSingleton.log.error("Error fetching list of PeyeDF events: \(response.result.error!)")
            } else {
                callback(JSON(response.result.value!))
            }
        }
    }
   
    /// Puts all reading events which are summary in the outgoing tuple, and fetches scientific documents
    /// (aka information elements) associated to each summary event.
    /// Can be used as a callback function for fetchAllPeyeDFEvents(...)
    private func fetchSummaryEvents(json: JSON) {
        missingInfoElems = 0
        outgoingSummaries = [(ev: SummaryReadingEvent, ie: ScientificDocument?)]()
        for readingEvent in json.arrayValue {
            outgoingSummaries.append((ev: SummaryReadingEvent(fromDime: readingEvent), ie: nil))
            missingInfoElems++
        }
        // convert info element ids to scientific documents and add them to outgoing data
        var i = 0
        for tuple in outgoingSummaries {
            getScientificDocument(i, infoElemId: tuple.ev.infoElemId as String)
            i++
        }
    }
    
    /// Gets a scientific document for a given index (referring to the outgoing tuple) and puts it in the appropriate place
    private func getScientificDocument(forIndex: Int, infoElemId: String) {
        DiMeFetcher.retrieveScientificDocument(infoElemId) {
            newScidoc in
            
            self.outgoingSummaries[forIndex].ie = newScidoc
            self.missingInfoElems--
            // all data has been fetched, send it
            if self.missingInfoElems == 0 {
                self.receiver.receiveAllSummaries(self.outgoingSummaries)
                }
            }
    }
    
}

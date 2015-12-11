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
    
    func receiveAllSummaries(tuples: [(ev: ReadingEvent, ie: ScientificDocument?)])
}

/// DiMeFetcher is supposed to be used as a singleton (via sharedFetcher)
class DiMeFetcher {
    
    /// Receiver of dime info. Delegate method will be called once fetching finishes.
    private let receiver: DiMeReceiverDelegate
    
    /// How many info elements still have to be fetched. When this number reaches 0, the delegate is called.
    private var missingInfoElems = Int.max
    
    /// Outgoing summary reading events and associate info elements
    private var outgoingSummaries = [(ev: ReadingEvent, ie: ScientificDocument?)]()
    
    init(receiver: DiMeReceiverDelegate) {
        self.receiver = receiver
    }
    
    /// Retrieves all summary information elements from dime and sends received data to the receiver.
    func getSummaries() {
        fetchAllPeyeDFEvents(fetchSummaryEvents)
    }
    
    /// Attempt to retrieve a single ScientificDocument from a given info element id.
    /// **Asynchronously** calls the given callback function once retrieval is complete.
    /// Called-back function will contain nil if retrieval failed.
    static func retrieveScientificDocument(infoElemId: String, callback: (ScientificDocument?) -> Void) {
        let server_url: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerURL) as! String
        let user: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerUserName) as! String
        let password: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerPassword) as! String
        
        let credentialData = "\(user):\(password)".dataUsingEncoding(NSUTF8StringEncoding)!
        let base64Credentials = credentialData.base64EncodedStringWithOptions([])
        
        let headers = ["Authorization": "Basic \(base64Credentials)"]
        
        var reqString: String
        switch PeyeConstants.dimeBranch {
        case .mongodb:
            reqString = server_url + "/data/informationelement/" + infoElemId
        case .sql:
            reqString = server_url + "/data/informationelements?appId=" + infoElemId
        }
        
        Alamofire.request(.GET, reqString, headers: headers).responseJSON() {
            response in
            if response.result.isFailure {
                AppSingleton.log.error("Error fetching information element: \(response.result.error!)")
                callback(nil)
            } else {
                // if this sql branch, assume first returned item is the one we are looking for
                let json: JSON
                switch PeyeConstants.dimeBranch {
                case .mongodb:
                    json = JSON(response.result.value!)
                case .sql:
                    json = JSON(response.result.value!)[0]
                }
                if let error = json["error"].string {
                    AppSingleton.log.error("Dime fetched json contains error:\n\(error)")
                }
                if let appId = json[PeyeConstants.iId].string {
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
    
    /// Retrieves all PeyeDF Reading events and calls the specified function once retrieval is complete
    private func fetchAllPeyeDFEvents(callback: (JSON) -> Void) {
        let server_url: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerURL) as! String
        let user: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerUserName) as! String
        let password: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerPassword) as! String
        
        let credentialData = "\(user):\(password)".dataUsingEncoding(NSUTF8StringEncoding)!
        let base64Credentials = credentialData.base64EncodedStringWithOptions([])
        
        let headers = ["Authorization": "Basic \(base64Credentials)"]
        
        Alamofire.request(.GET, server_url + "/data/events?actor=PeyeDF&type=http://www.hiit.fi/ontologies/dime/%23ReadingEvent", headers: headers).responseJSON() {
            response in
            if response.result.isFailure {
                AppSingleton.log.error("Error fetching list of PeyeDF events: \(response.result.error!)")
            } else {
                callback(JSON(response.result.value!))
            }
        }
    }
   
    /// Puts all reading events which are summary in the outgoing tuple, and fetches scientific documents
    /// (aka information elements) associated to each summary event
    private func fetchSummaryEvents(json: JSON) {
        missingInfoElems = 0
        outgoingSummaries = [(ev: ReadingEvent, ie: ScientificDocument?)]()
        for readingEvent in json.arrayValue {
            if readingEvent["isSummary"].boolValue {
                outgoingSummaries.append((ev: ReadingEvent(asManualSummaryFromDime: readingEvent), ie: nil))
                missingInfoElems++
            }
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

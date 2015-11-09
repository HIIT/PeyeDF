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
    
    /// Outgoing reading events and associate info elements
    private var outgoing = [(ev: ReadingEvent, ie: ScientificDocument?)]()
    
    init(receiver: DiMeReceiverDelegate) {
        self.receiver = receiver
    }
    
    /// Retrieves all summary information elements from dime and sends received data to the receiver.
    func getSummaries() {
        let server_url: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerURL) as! String
        let user: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerUserName) as! String
        let password: String = NSUserDefaults.standardUserDefaults().valueForKey(PeyeConstants.prefDiMeServerPassword) as! String
        
        let credentialData = "\(user):\(password)".dataUsingEncoding(NSUTF8StringEncoding)!
        let base64Credentials = credentialData.base64EncodedStringWithOptions([])
        
        let headers = ["Authorization": "Basic \(base64Credentials)"]
        
        Alamofire.request(.GET, server_url + "/data/events?actor=PeyeDF&type=http://www.hiit.fi/ontologies/dime/%23ReadingEvent", headers: headers).responseJSON() {
            _, _, response in
            if response.isFailure {
                AppSingleton.log.error("Error fetching list of PeyeDF events: \(response.debugDescription)")
            } else {
                self.convertJsonSummary(JSON(response.value!))
            }
        }
    }
    
    /// Attempt to retrieve a single ScientificDocument from a given info element id.
    /// Calls the given callback function once retrieval is complete.
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
            _, _, response in
            if response.isFailure {
                AppSingleton.log.error("Error fetching information element: \(response.debugDescription)")
                callback(nil)
            } else {
                // if this sql branch, assume first returned item is the one we are looking for
                let json: JSON
                switch PeyeConstants.dimeBranch {
                case .mongodb:
                    json = JSON(response.value!)
                case .sql:
                    json = JSON(response.value!)[0]
                }
                if let error = json["error"].string {
                    AppSingleton.log.error("Dime fetched json contains error:\n\(error)")
                }
                if let appId = json[PeyeConstants.iId].string {
                    if appId == infoElemId {
                        let newScidoc = ScientificDocument(fromJson: json)
                        callback(newScidoc)
                    } else {
                        AppSingleton.log.error("Retrieved info element id does not match requested id: \(response.value!)")
                        callback(nil)
                    }
                } else {
                    AppSingleton.log.debug("Failed to retrieve a valid info element: \(response.value!)")
                    callback(nil)
                }
            }
        }
    }
   
    private func convertJsonSummary(json: JSON) {
        missingInfoElems = 0
        outgoing = [(ev: ReadingEvent, ie: ScientificDocument?)]()
        for readingEvent in json.arrayValue {
            if readingEvent["isSummary"].boolValue {
                outgoing.append((ev: ReadingEvent(asManualSummaryFromDime: readingEvent), ie: nil))
                missingInfoElems++
            }
        }
        // convert info element ids to scientific documents and add them to outgoing data
        var i = 0
        for tuple in outgoing {
            getScientificDocument(i, infoElemId: tuple.ev.infoElemId as String)
            i++
        }
    }
    
    /// Gets a scientific document for a given index (referring to the outgoing tuple) and puts it in the appropriate place
    private func getScientificDocument(forIndex: Int, infoElemId: String) {
        DiMeFetcher.retrieveScientificDocument(infoElemId) {
            newScidoc in
            
            self.outgoing[forIndex].ie = newScidoc
            self.missingInfoElems--
            // all data has been fetched, send it
            if self.missingInfoElems == 0 {
                self.receiver.receiveAllSummaries(self.outgoing)
                }
            }
    }
}

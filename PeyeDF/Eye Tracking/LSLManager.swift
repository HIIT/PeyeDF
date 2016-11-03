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

/// The LSLManager provides eye tracking data using LabStreamingLayer.
/// It is responsible for creating the LSL streams (using LSLFetcher instances) and checking that data is correctly formed.
class LSLManager: EyeDataProvider {
    
    // MARK: - Constants
    
    /// If eyes are lost for this whole period (seconds) an eye lost notification is sent
    let kEyesMaxLostDuration: TimeInterval = 7.0
    
    // MARK: - EyeDataProvider fields
    
    /// Returns true if all LSL streams were successfully activated
    private(set) var available: Bool = false

    var fixationDelegate: FixationDataDelegate?

    private(set) var eyesLost: Bool = true { didSet {
        if eyesLost != oldValue {
            eyeStateChange(available: !eyesLost)
        }
    } }
    
    private(set) var lastValidDistance: CGFloat = 800.0
    
    // MARK: - LSL Stream objects references
    
    private var rawStream: LSLFetcher<RawEyePosition>?
    private var eventStream: LSLFetcher<FixationEvent>?
    
    // MARK: - EyeDataProvider functions
    
    /// Opens the lsl streams
    func start() {
        let rawSuccess = rawStream?.start() ?? false
        let fixationSuccess = eventStream?.start() ?? false
        if rawSuccess && fixationSuccess {
            eyeConnectionChange(available: true)
            available = true
        } else {
            AppSingleton.log.error("Failed to initialize both LSL streams")
            eyeConnectionChange(available: false)
            available = false
        }
    }
    
    /// Stops the lsl streams
    func stop() {
        rawStream?.stop()
        eventStream?.stop()
        eyeConnectionChange(available: false)
        available = false
    }
    
    // MARK: - Private instance variables (for data processing)
    
    /// Last time we received a raw eye position timestamp
    private var lastRawTimestamp = Int.min
    
    /// Start time of the last fixation we received
    private var lastFixationStart = Int.min
    
    /// Last time that eyes were detected
    private var eyesLastSeen = Date.distantPast
    
    // MARK: - Initialization and callback definition
    
    init() {
        
        let rawDataCallback: (Double, RawEyePosition?) -> Void = {
            _, rawPosition in
            
            guard let rawPosition = rawPosition, !rawPosition.zeroed() else {
                // no data found in this sample
                
                // if eyes are currently indicated as available, but too much time has passed,
                // change eye status
                return
            }
            
            // check that this timestamp is later than the latest received timestamp before proceeding
            
            self.lastRawTimestamp = rawPosition.timestamp
            self.eyesLastSeen = Date()
        }
        
        let fixationDataCallback: (Double, FixationEvent?) -> Void = {
            _, fixationEvent in
            
            guard let fixationEvent = fixationEvent else {
                return
            }
            
            // check that this fixation start is bigger than the latest received fixation
            // start before proceeding
            
            
            self.lastFixationStart = fixationEvent.startTime
        }
        
        rawStream = LSLFetcher<RawEyePosition>(name: "SMI_Raw", dataCallback: rawDataCallback)
        eventStream = LSLFetcher<FixationEvent>(name: "SMI_Event", dataCallback: fixationDataCallback)
    }
}

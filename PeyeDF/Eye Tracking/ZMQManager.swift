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

class ZMQManager: EyeDataProvider {
    
    /// If eyes are lost for this whole period (seconds) an eye lost notification is sent
    let kEyesMaxLostDuration: TimeInterval = 7.0
    
    /// Last time that eyes were detected
    private var eyesLastSeen = Date.distantPast
    
    /// The delegate to which fixation data will be sent
    var fixationDelegate: FixationDataDelegate?
    
    /// Dispatch queue on which data is fetched
    let queue = DispatchQueue(label: "ZMQueue", qos: DispatchQoS.default)
    
    /// True while fetching data
    var fetch = true
    
    /// Is true if connection is alive
    private(set) var available: Bool = false { didSet {
        eyeConnectionChange(available: available)
    } }
    
    /// Whether eyes are lost
    // TODO: set this
    private(set) var eyesLost: Bool = false { didSet {
        eyeStateChange(available: !eyesLost)
    } }
    
    /// Returns the last known distance of the user from the screen.
    /// Since this is not supported, just return 800
    private(set) var lastValidDistance: CGFloat = 800

    /// ZMQ Context
    let context = try! Context()
    
    /// Port for pupil labs capture remote
    let port = 50020
    
    /// Screen size represented by markers
    
    let minX: Double = 24
    let maxX: Double = 1660
    let minY: Double = 20
    let maxY: Double = 1006
    
    func start() {
        
        /// ZMQ Requester
        let requester = try! context.socket(.req)
        
        try! requester.connect("tcp://127.0.0.1:\(port)")
        
        guard try! requester.send("SUB_PORT") == true else {
            AppSingleton.log.error("Failed to connect to ZeroMQ pupil on port: \(self.port)")
            return
        }

        // get port for data transfer
        let sub_port: Data = try! requester.receive()!
        let sub_port_string = String(data: sub_port, encoding: .utf8)!
        
        available = true
        
        // Check if eyes will be lost in the future
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + self.kEyesMaxLostDuration) {self.lostCheck()}
        
        queue.async {
        
            // subscribe to all updates on port for data transfer
            let socket = try! self.context.socket(.sub)
            try! socket.connect("tcp://127.0.0.1:\(sub_port_string)")
            try! socket.setOption(ZMQ_SUBSCRIBE, "surface")
            
            while self.fetch {
                let msg: Message? = try! socket.receiveMessage()
                if let msg = msg {
                    // if there's more, this message is a string (topic)
                    // otherwise, this message is a messagepack
                    let msgdata = Data.init(bytes: msg.data, count: msg.size)
                    if msg.more {
                        // message is a string (topic)
                        let topic = String(data: msgdata, encoding: .utf8)!
                        // verify that topic is "surface"
                        if topic != "surface" {
                            AppSingleton.log.warning("Unexpected topic found: \(topic)")
                        }
                        
                    } else {
                        // message is a messagepack
                        
                        // we take the first value found in the arrays
                        // (they should contain 1 value anyway)
                        
                        let packArray = try! unpackAll(msgdata)
                        let dict = packArray[0].dictionaryValue!
                        
                        // make sure we have some fixations
                        guard let fixArray = dict["fixations_on_srf"]?.arrayValue, fixArray.count > 0 else {
                            continue
                        }
                        
                        let surfData = fixArray[0]
                        
                        // skip if gaze is not in surface
                        if surfData["on_srf"]!.boolValue! == false {
                            continue
                        }
                        
                        // Get Position from surface
                        let pos = surfData["norm_pos"]!.arrayValue!
                        
                        // Check if eyes were previous lost and update the last time we saw them
                        if self.eyesLost {
                            self.eyesLost = false
                        }
                        self.eyesLastSeen = Date()
                        
                        // Check if eyes will be lost in the future
                        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + self.kEyesMaxLostDuration + 0.001) {self.lostCheck()}
                        
                        // We invert y since origin is on bottom left and FixationEvent uses top left origin
                        let newY = (1 - pos[1].doubleValue!)
                        let sx = translate(pos[0].doubleValue!, leftMin: 0, leftMax: 1, rightMin: self.minX, rightMax: self.maxX)
                        let sy = translate(newY, leftMin: 0, leftMax: 1, rightMin: self.minY, rightMax: self.maxY)
                        
                        // Get Fixation Data
                        
                        let fixData = surfData["base_data"]!.dictionaryValue!
                        
                        // Assume eye == 0 curresponds to right eye and 1 to left eye
                        let eye: Eye
                        if fixData["eye_id"]!.unsignedIntegerValue! == 0 {
                            eye = .right
                        } else {
                            eye = .left
                        }
                        
                        // Diameter seems to be received in tenths of mm
                        let diameter = fixData["pupil_diameter"]!.doubleValue! / 10
                        
                        // Timestamp is seconds since start, convert to ns and round
                        let timestamp = Int(round(fixData["timestamp"]!.doubleValue! * 1000000000))
                        
                        // Duration is received in seconds, convert to ns and round
                        let duration = Int(round(fixData["duration"]!.doubleValue! * 1000000000))
                        
                        print("t:\(timestamp),d:\(duration),e:\(eye)")
                        
                        // send data
                        let fix = FixationEvent(eye: eye, startTime: timestamp, endTime: timestamp + duration, duration: duration, positionX: sx, positionY: sy, unixtime: Date().unixTime, pupilSize: diameter)
                        self.fixationDelegate?.receiveNewFixationData([fix])
                    }
                    
                } else {
                    print("Received empty message")
                }
            }
            
            self.available = false
            try! socket.close()
            try! requester.close()
            
        }
        
    }
    
    func stop() {
        self.fetch = false
    }
    
    /// This block is called a fixed amount of seconds after the
    /// last fixation was received. If no fixations were received
    /// since, the eyes are marked as lost.
    func lostCheck() {
        // if eyes are currently indicated as available, but too much time has passed,
        // change eye status
        if !self.eyesLost && self.eyesLastSeen.addingTimeInterval(self.kEyesMaxLostDuration).compare(Date()) == .orderedAscending {
            self.eyesLost = true
        }
    }
}

/// Given a value and an input range, return a value in the output range
private func translate(_ value: Double, leftMin: Double, leftMax: Double, rightMin: Double, rightMax: Double) -> Double {
    // Figure out how 'wide' each range is
    let leftSpan = leftMax - leftMin
    let rightSpan = rightMax - rightMin
    
    // Convert the left range into a 0-1 range (float)
    let valueScaled = (value - leftMin) / leftSpan
    
    // Convert the 0-1 range into a value in the right range.
    return rightMin + (valueScaled * rightSpan)
}

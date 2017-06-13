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

/// Provides support for pupil labs ZMQ interface.
/// Does not support distance from screen and is less accurate, but provides a more reliable pupil size measurement.
class ZMQManager: EyeDataProvider {
        
    /// Last time that eyes were detected
    private var eyesLastSeen = Date.distantPast
    
    /// The delegate to which fixation data will be sent
    var fixationDelegate: FixationDataDelegate?
    
    /// Dispatch queue on which data is fetched
    let queue = DispatchQueue(label: "ZMQueue", qos: DispatchQoS.default)
    
    /// True while fetching data
    var fetch = true
    
    /// Set to true if we are running pupil capture with only one eye.
    /// We'll warn the user if we receive data for an eye which is not set as
    /// the dominant one
    let singleEye = true
    
    /// Become true once we warn the user once about receiving data for the "wrong" eye
    /// and singleEye is true
    var warnedUser = false
    
    /// Is true if connection is alive
    private(set) var available: Bool = false { didSet {
        eyeConnectionChange(available: available)
    } }
    
    /// Whether eyes are lost
    private(set) var eyesLost: Bool = false { didSet {
        eyeStateChange(available: !eyesLost)
    } }
    
    /// Returns the last known distance of the user from the screen.
    /// Since this is not supported, just return 800
    private(set) var lastValidDistance: CGFloat = 800

    /// ZMQ Context
    let context: Context! = {
        var ctx: Context? = nil
        do {
            ctx = try Context()
        } catch {
            AppSingleton.log.error("Error while creating ZeroMQ Context: \(error). Pupil labs data will be unavailable.")
        }
        return ctx
    }()
    
    /// Port for pupil labs capture remote
    let port = 50020
    
    /// Screen size represented by markers
    
    let minX: Double = 24
    let maxX: Double = 1660
    let minY: Double = 20
    let maxY: Double = 1006
    
    func start() {
        
        guard context != nil else {
            return
        }
        
        // async queue for connection and loop for data fetching
        queue.async {
            
            /// ZMQ Requester
            var sub_port_string = ""  // if this won't be set to something non-empty, we won't be able to connect
            do {
                let requester = try self.context.socket(.req)
                
                try requester.connect("tcp://127.0.0.1:\(self.port)")
                
                guard try requester.send("SUB_PORT") == true else {
                    AppSingleton.log.error("Failed to connect to ZeroMQ pupil on port: \(self.port)")
                    return
                }

                // get port for data transfer
                if let sub_port: Data = try requester.receive(), let _sub_port_string = String(data: sub_port, encoding: .utf8) {
                    sub_port_string = _sub_port_string
                }
                
                try requester.close()
            } catch {
                AppSingleton.log.error("Error while connecting to pupil capture: \(error)")
                self.available = false
                return
            }
            
            // Check if eyes will be lost in the future
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + PeyeConstants.eyesMaxLostDuration) {self.lostCheck()}
        
            // socket for fetching data
            var socket: Socket!
        
            // subscribe to all updates on port for data transfer
            do {
                socket = try self.context.socket(.sub)
                try socket.connect("tcp://127.0.0.1:\(sub_port_string)")
                try socket.setOption(ZMQ_SUBSCRIBE, "surface")
            } catch {
                AppSingleton.log.error("Failed to create zmq socket: \(error)")
                return
            }
            
            // report successful connection
            self.available = true
            
            // data fetch loop
            while self.fetch {
                var _msg: Message!
                do {
                    _msg = try socket.receiveMessage()
                } catch {
                    AppSingleton.log.error("Failed to receive message from zmq subscription: \(error).")
                    continue
                }
                
                guard let msg = _msg else {
                    continue
                }
                
                // if there's more, this message is a string (topic)
                // otherwise, this message is a messagepack
                let msgdata = Data.init(bytes: msg.data, count: msg.size)
                if msg.more {
                    // message is a string (topic)
                    let topic: String? = String(data: msgdata, encoding: .utf8)
                    // verify that topic is "surface"
                    if topic ?? "" != "surfaces" {
                        AppSingleton.log.warning("Unexpected topic found: \(topic ?? "N/A")")
                        continue
                    }
                    
                } else {
                    // message is a messagepack
                    
                    // we take the first value found in the arrays
                    // (they should contain 1 value anyway)
                    var packArray: [MessagePackValue]!
                    do {
                        packArray = try unpackAll(msgdata)
                    } catch {
                        AppSingleton.log.error("Failed to unpack message: \(error)")
                        continue
                    }
                    
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
                    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + PeyeConstants.eyesMaxLostDuration + 0.001) {self.lostCheck()}
                    
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
                    
                    // If we are in single eye mode, warn user about receiving data for the "wrong" eye
                    if self.singleEye && !self.warnedUser && eye != AppSingleton.dominantEye {
                        self.warnedUser = true
                        AppSingleton.alertUser("ZMQ Manager: received data for \(eye) eye, but dominant eye is set to \(AppSingleton.dominantEye).")
                    }
                    
                    // Diameter seems to be received in tenths of mm
                    let diameter = fixData["pupil_diameter"]!.doubleValue! / 10
                    
                    // Timestamp is seconds since start, convert to ns and round
                    let timestamp = Int(round(fixData["timestamp"]!.doubleValue! * 1000000000))
                    
                    // Duration is received in seconds, convert to ns and round
                    let duration = Int(round(fixData["duration"]!.doubleValue! * 1000000000))
                    
                    // send data
                    let fix = FixationEvent(eye: eye, startTime: timestamp, endTime: timestamp + duration, duration: duration, positionX: sx, positionY: sy, unixtime: Date().unixTime, pupilSize: diameter)
                    self.sendFixations([fix])
                }
                
            } // end of data fetch loop
            
            self.available = false
            
            do {
                try socket.close()
            } catch {
                AppSingleton.log.error("Failed to close zmq socket: \(error)")
            }
            
        } // end of async data queue
        
    }
    
    func stop() {
        self.fetch = false
    }
    
    /// This block is called (repeatedly) a fixed amount of seconds after each
    /// last fixation is received. If no fixations were received
    /// since the last call + some time, the eyes are marked as lost.
    func lostCheck() {
        // if eyes are currently indicated as available, but too much time has passed,
        // change eye status
        if !self.eyesLost && self.eyesLastSeen.addingTimeInterval(PeyeConstants.eyesMaxLostDuration).compare(Date()) == .orderedAscending {
            self.eyesLost = true
        }
    }
}

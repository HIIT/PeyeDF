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
    private(set) var eyesLost: Bool = false
    
    /// Returns the last known distance of the user from the screen
    // TODO: set this
    private(set) var lastValidDistance: CGFloat = 0

    /// ZMQ Context
    let context = try! Context()
    
    /// Port for pupil labs capture remote
    let port = 50020
    
    /// Screen size represented by markers
    
    let minX: Double = 22
    let maxX: Double = 1635
    let minY: Double = 20
    let maxY: Double = 985
    
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
                        // verify that topic is "surface"
                        let topic = String(data: msgdata, encoding: .utf8)!
                        
                    } else {
                        // message is a messagepack
                        
                        // make sure pack array count is 1
                        
                        let packArray = try! unpackAll(msgdata)
//                        print("Pack array descr: \(packArray.description)")
                        let dict = packArray[0].dictionaryValue!
                        
                        guard let arrayval = dict[MessagePackValue.string("gaze_on_srf")]?.arrayValue, arrayval.count > 0 else {
                            continue
                        }
                        
                        let val = arrayval[0]
                        let pos = val[MessagePackValue.string("norm_pos")]!.arrayValue!
//                        print("pos x:\(pos[0].doubleValue!) y:\(pos[1].doubleValue!)")
                        // invert y since it seems similar to osx
                        let newY = (1 - pos[1].doubleValue!)
                        // MUST DOCUMENT X AND Y OF FixationEvent
                        let sx = translate(pos[0].doubleValue!, leftMin: 0, leftMax: 1, rightMin: self.minX, rightMax: self.maxX)
                        let sy = translate(newY, leftMin: 0, leftMax: 1, rightMin: self.minY, rightMax: self.maxY)
                        let fix = FixationEvent(eye: .right, startTime: -1, endTime: -1, duration: -1, positionX: sx, positionY: sy, unixtime: -1)
                        print("sent: \(sx),\(sy)")
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

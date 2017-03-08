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

/// The FixationDataDelegate receives fixation data (calibrated) from the EyeDataProvider
protocol FixationDataDelegate: class {
    
    /// Receives new fixations. This is called automatically by `EyeDataProvider` adopters (assuming they correctly call `sendFixations`).
    func receiveNewFixationData(_ newData: [FixationEvent])
}

/// The EyeDataProvider protocol is used to generalise support for any eye tracker. For example, the MidasManager implements this protocol by frequently polling Midas to retrieve the lasest chunk of data in a buffer.
/// It is a class protocol since normally it would be implemented by a singleton.
/// The EyeDataProvider is also responsible for sending a `PeyeConstants.midasEyePositionNotification` Notification which should contain the latest RawEyePosition as part of its userInfo dictionary (see the sendLastRaw(_) method).
protocol EyeDataProvider: class {
    
    /// The delegate to which fixation data will be sent
    var fixationDelegate: FixationDataDelegate? { get set }
    
    /// Check whether the provider is available (e.g. connection is alive)
    var available: Bool { get }
    
    /// Check whether the user's eyes can't be detected
    var eyesLost: Bool { get }
    
    /// Returns the last known distance of the user from the screen
    var lastValidDistance: CGFloat { get }
    
    /// Should cause the EyeDataProvider to start calling receiveNewFixationData on its delegate when new data is available
    func start()
    
    /// Stops calling receiveNewFixationData on its delegate(s)
    func stop()
    
}

extension EyeDataProvider {
    
    /// `EyeDataProvider`s should call this method as soon as they receive a raw eye position (which is used to update user's head position).
    func sendLastRaw(_ lastPos: RawEyePosition) {
        NotificationCenter.default.post(name: PeyeConstants.eyePositionNotification, object: self, userInfo: lastPos.asDict())
    }
    
    /// `EyeDataProvider`s should call this as soon as they receive new fixations
    func sendFixations(_ newData: [FixationEvent]) {
        // if there's an offset, apply it to the newly sent data
        if AppSingleton.eyeOffset != [0, 0] {
            var adjustedData = newData
            for i in 0..<adjustedData.count {
                adjustedData[i].positionX += Double(AppSingleton.eyeOffset[0])
                adjustedData[i].positionY += Double(AppSingleton.eyeOffset[1])
            }
            fixationDelegate?.receiveNewFixationData(adjustedData)
        } else {
            fixationDelegate?.receiveNewFixationData(newData)
        }
    }
    
    /// This method should be called as soon as the state of the user's eye changes from found to lost, or vice-versa
    func eyeStateChange(available: Bool) {
        NotificationCenter.default.post(name: PeyeConstants.eyesAvailabilityNotification, object: self, userInfo: ["available": available])
    }
    
    /// This method should be called as soon as the state of the eye tracker connection changes.
    func eyeConnectionChange(available: Bool) {
        NotificationCenter.default.post(name: PeyeConstants.eyeConnectionNotification, object: self, userInfo: ["available": available])
    }
}

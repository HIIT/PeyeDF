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
import MultipeerConnectivity

// requestStatus:
// trackingChange:<"true"/"false">
// requestFile:contentHash
// readingDocument:filename::contentHash::title  (where title can be empty)
// reportIdle:
// scrollTo:<FocusArea description>  (a peer scrolled to some area - normally a point)
// addReadingTag:<ReadingTag description>  (a peer added this tag to the currently tracked document)
// removeReadingTag:<ReadingTag description>  (a peer added this tag to the currently tracked document)
// readAreas:<FocusAreas description>  (a peer read a numbers of areas, separated by ; - normally areas are rects)
// markRects:<JSON Raw String>  (a peer marked some readingrects)

enum MessagePrefix: String {
    case reportIdle
    case requestStatus
    case trackingChange
    case requestFile
    case readingDocument
    case scrollTo
    case addReadingTag
    case removeReadingTag
    case readAreas
    case markRects
}

enum CollaborationMessage {
    
    /// This message tells that a given peer is idle (closed open window / doing nothing)
    case reportIdle
    
    /// This message, when received, causes us to send our status (ReadingDocument) to the sender
    case requestStatus
    
    /// We tell other peers that we started tracking them or they tell us they started tracking us
    case trackingChange(newState: Bool)
    
    /// This message, when received, causes to send the file we are currently reading to the sender
    case requestFile(contentHash: String)
    
    /// This message notifies that we are reading a specific document, and identifies that file
    case readingDocument(filename: String, contentHash: String, paperTitle: String?)
    
    /// Notifies peers that we scrolled to some area
    case scrollTo(area: FocusArea)
    
    /// Notifies peers that we created a reading tag
    case addReadingTag(ReadingTag)
    
    /// Notifies peers that we removed a tag
    case removeReadingTag(ReadingTag)
    
    /// Notifies peers that we read a number of areas
    case readAreas([FocusArea])
    
    /// Notifies peers that we marked a number of rects
    case markRects([ReadingRect])
    
    /// Creates a started reading message using the current scidoc.
    /// - Attention: No message will be created if the scidoc is nil or does not have an associated contenthash.
    init?(readingDocumentFromSciDoc sciDoc: ScientificDocument?) {
        guard let sciDoc = sciDoc, let cHash = sciDoc.contentHash else {
            return nil
        }
        let fnameUrl = URL(fileURLWithPath: sciDoc.uri)
        let fname = fnameUrl.lastPathComponent
        self = CollaborationMessage.readingDocument(filename: fname, contentHash: cHash, paperTitle: sciDoc.title)
    }
    
    /// Creates a collaboration message from raw data (for example data that is received from network peers).
    init?(fromData: Data) {
        // convert data to string and make sure there is at least one ':'
        guard let string = String(data: fromData, encoding: String.Encoding.utf8),
              let r = string.range(of: ":") else {
            return nil
        }
        
        // split using :
        let prefix = string.substring(to: r.lowerBound)
        let suffix = string.substring(from: r.upperBound)
        
        guard let parsedPrefix = MessagePrefix(rawValue: prefix) else {
            AppSingleton.log.error("Failed to parse prefix: \(prefix)")
            return nil
        }
        
        switch parsedPrefix {
            
        case .reportIdle:
            self = .reportIdle
            
        case .requestStatus:
            self = .requestStatus
            
        case .trackingChange:
            self = .trackingChange(newState: (suffix as NSString).boolValue)
            
        case .readingDocument:
            // split filename, contenthash and title components
            let components = suffix.components(separatedBy: "::")
            guard components.count == 3 else {
                return nil
            }
            let fileName = components[0]
            let contentHash = components[1]
            var title: String?
            if !components[2].isEmpty {
                title = components[2]
            }
            self = .readingDocument(filename: fileName, contentHash: contentHash, paperTitle: title)
            
        case .requestFile:
            self = .requestFile(contentHash: suffix)
            
        case .scrollTo:
            
            guard let area = FocusArea(fromString: suffix) else {
                AppSingleton.log.error("Could not convert string to focus area")
                return nil
            }
            
            self = .scrollTo(area: area)
            
        case .addReadingTag:
            
            guard let tag = ReadingTag(fromString: suffix, pdfBase: nil) else {
                AppSingleton.log.error("Failed to parse tag string")
                return nil
            }
            
            self = .addReadingTag(tag)
            
        case .removeReadingTag:
            
            guard let tag = ReadingTag(fromString: suffix, pdfBase: nil) else {
                AppSingleton.log.error("Failed to parse tag string")
                return nil
            }
            
            self = .removeReadingTag(tag)
            
        case .readAreas:
            
            let inputAreas = suffix.components(separatedBy: ";")
            let parsedAreas = inputAreas.flatMap({FocusArea(fromString: $0)})
            guard parsedAreas.count > 0 else {
                AppSingleton.log.error("Failed to find any areas in input")
                return nil
            }
            self = .readAreas(parsedAreas)
            
        case .markRects:
            
            let json = JSON.parse(suffix)
            AppSingleton.log.debug("Received json count: \(json.count)")
            self = .markRects(json.array!.flatMap({ReadingRect(fromJson: $0)}))
        }
    }
    
    /// Gets the string that identifies a message, for this collaboration message (does not include `:`).
    func prefix() -> String {
        switch self {
        case .reportIdle:
            return MessagePrefix.reportIdle.rawValue
        case .requestStatus:
            return MessagePrefix.requestStatus.rawValue
        case .trackingChange:
            return MessagePrefix.trackingChange.rawValue
        case .readingDocument:
            return MessagePrefix.readingDocument.rawValue
        case .requestFile:
            return MessagePrefix.requestFile.rawValue
        case .scrollTo:
            return MessagePrefix.scrollTo.rawValue
        case .addReadingTag:
            return MessagePrefix.addReadingTag.rawValue
        case .removeReadingTag:
            return MessagePrefix.removeReadingTag.rawValue
        case .readAreas:
            return MessagePrefix.readAreas.rawValue
        case .markRects:
            return MessagePrefix.markRects.rawValue
        }
    }
    
    /// Generates a string from this collaboration message (so that it can be sent to peers).
    func buildMessage() -> String {
        switch self {
        case .reportIdle:
            return self.prefix() + ":"
        case .requestStatus:
            return self.prefix() + ":"
        case .trackingChange(let newState):
            return self.prefix() + ":" + newState.description
        case .readingDocument(let filename, let contentHash, let paperTitle):
            return self.prefix() + ":" + filename + "::" + contentHash + "::" + (paperTitle ?? "")
        case .requestFile(let contentHash):
            return self.prefix() + ":" + contentHash
        case .scrollTo(let area):
            return self.prefix() + ":" + area.description
        case .addReadingTag(let tag):
            return self.prefix() + ":" + tag.description
        case .removeReadingTag(let tag):
            return self.prefix() + ":" + tag.description
        case .readAreas(let areas):
            return self.prefix() + ":" + areas.map({$0.description}).joined(separator: ";")
        case .markRects(let rects):
            var outDict = [[String: Any]]()
            for rect in rects {
                var newRect = rect
                newRect.plainTextContent = nil
                outDict.append(newRect.getDict())
            }
            let jsonData = try! JSONSerialization.data(withJSONObject: outDict, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8)!
            return self.prefix() + ":" + jsonString
        }
    }
    
    /// Sends itself to the given list of peers.
    /// Can set mode to unreliable if wanted (defaults to reliable).
    func sendTo(_ peers: [MCPeerID], _ mode: MCSessionSendDataMode = .reliable) {
        let data = buildMessage().data(using: String.Encoding.utf8)!
        do {
            try Multipeer.session.send(data, toPeers: peers, with: mode)
        } catch {
            AppSingleton.log.error("Failed to send message '\(self.buildMessage())' to peers: \(error)")
        }
    }
    
    /// Sends itself to all connected peers.
    func sendToAll(_ mode: MCSessionSendDataMode = .reliable) {
        let peers = Multipeer.session.connectedPeers
        guard peers.count > 0 else {
            return
        }
        sendTo(peers, mode)
    }
    
}

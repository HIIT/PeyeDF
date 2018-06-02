//
// Copyright (c) 2018 University of Helsinki, Aalto University
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
import os.log

// requestStatus:
// trackingChange:<"true"/"false">
// requestFile:contentHash
// readingDocument:filename::contentHash::title  (where title can be empty)
// reportIdle:
// scrollTo:<FocusArea(.point) description>  (a peer scrolled to some area)
// addReadingTag:<ReadingTag description>  (a peer added this tag to the currently tracked document)
// removeReadingTag:<ReadingTag description>  (a peer added this tag to the currently tracked document)
// seenAreas:<FocusAreas description>  (a peer just saw or read 1 or more)
// markRects:<JSON Raw String>  (a peer marked some readingrects)
// fixation:<FocusArea(.point) description>  (new fixation received from peer)
// undo:  (undo last marking)
// redo:  (redo last marking)

enum MessagePrefix: String {
    case reportIdle
    case requestStatus
    case trackingChange
    case requestFile
    case readingDocument
    case scrollTo
    case addReadingTag
    case removeReadingTag
    case seenAreas
    case markRects
    case fixation
    case undo
    case redo
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
    
    /// Notifies peers that we just seen (read) a number of areas
    case seenAreas([FocusArea])
    
    /// Notifies peers that we marked a number of rects
    case markRects([ReadingRect])
    
    /// Notifies that a new fixation was received from eye tracker
    case fixation(FocusArea)
    
    /// Notifies that we pressed undo or ⌘Z
    case undo
    
    /// Notofies that we pressed redo or ⇧⌘Z
    case redo
    
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
        let prefix = String(string[..<r.lowerBound])
        let suffix = String(string[r.upperBound...])
        
        guard let parsedPrefix = MessagePrefix(rawValue: prefix) else {
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
                if #available(OSX 10.12, *) {
                    os_log("Could not convert string to focus area", type: .debug)
                }
                return nil
            }
            
            self = .scrollTo(area: area)
            
        case .addReadingTag:
            
            guard let tag = ReadingTag(fromString: suffix, pdfBase: nil) else {
                if #available(OSX 10.12, *) {
                    os_log("Failed to parse tag string", type: .debug)
                }
                return nil
            }
            
            self = .addReadingTag(tag)
            
        case .removeReadingTag:
            
            guard let tag = ReadingTag(fromString: suffix, pdfBase: nil) else {
                if #available(OSX 10.12, *) {
                    os_log("Failed to parse tag string", type: .debug)
                }
                return nil
            }
            
            self = .removeReadingTag(tag)
            
        case .seenAreas:
            
            let inputAreas = suffix.components(separatedBy: ";")
            let parsedAreas = inputAreas.compactMap({FocusArea(fromString: $0)})
            guard parsedAreas.count > 0 else {
                if #available(OSX 10.12, *) {
                    os_log("Failed to find any areas in input", type: .debug)
                }
                return nil
            }
            self = .seenAreas(parsedAreas)
            
        case .markRects:
            
            let json = JSON(parseJSON: suffix)
            self = .markRects(json.array!.compactMap({ReadingRect(fromJson: $0)}))
        
        case .fixation:
        
            guard let area = FocusArea(fromString: suffix) else {
                if #available(OSX 10.12, *) {
                    os_log("Failed to parse fixation string", type: .debug)
                }
                return nil
            }
        
            self = .fixation(area)
            
        case .undo:
            self = .undo
            
        case .redo:
            self = .redo
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
        case .seenAreas:
            return MessagePrefix.seenAreas.rawValue
        case .markRects:
            return MessagePrefix.markRects.rawValue
        case .fixation:
            return MessagePrefix.fixation.rawValue
        case .undo:
            return MessagePrefix.undo.rawValue
        case .redo:
            return MessagePrefix.redo.rawValue
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
        case .seenAreas(let areas):
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
        case .fixation(let area):
            return self.prefix() + ":" + area.description
        case .undo:
            return self.prefix() + ":"
        case .redo:
            return self.prefix() + ":"
        }
    }
    
    /// Sends itself to the given list of peers.
    /// Can set mode to unreliable if wanted (defaults to reliable).
    func sendTo(_ peers: [MCPeerID], _ mode: MCSessionSendDataMode = .reliable) {
        let data = buildMessage().data(using: String.Encoding.utf8)!
        do {
            try Multipeer.session.send(data, toPeers: peers, with: mode)
        } catch {
            if #available(OSX 10.12, *) {
                os_log("Failed to send message to peers: %@", type: .fault, error.localizedDescription)
            }
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

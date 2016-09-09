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
}

enum CollaborationMessage {
    
    /// This message tells that a given peer is idle (closed open window / doing nothing)
    case ReportIdle
    
    /// This message, when received, causes us to send our status (ReadingDocument) to the sender
    case RequestStatus
    
    /// We tell other peers that we started tracking them or they tell us they started tracking us
    case TrackingChange(newState: Bool)
    
    /// This message, when received, causes to send the file we are currently reading to the sender
    case RequestFile(contentHash: String)
    
    /// This message notifies that we are reading a specific document, and identifies that file
    case ReadingDocument(filename: String, contentHash: String, paperTitle: String?)
    
    /// Notifies peers that we scrolled to some area
    case ScrollTo(area: FocusArea)
    
    /// Notifies peers that we created a reading tag
    case AddReadingTag(ReadingTag)
    
    /// Notifies peers that we removed a tag
    case RemoveReadingTag(ReadingTag)
    
    /// Notifies peers that we read a number of areas
    case ReadAreas([FocusArea])
    
    /// Creates a started reading message using the current scidoc.
    /// - Attention: No message will be created if the scidoc is nil or does not have an associated contenthash.
    init?(readingDocumentFromSciDoc sciDoc: ScientificDocument?) {
        guard let sciDoc = sciDoc, cHash = sciDoc.contentHash else {
            return nil
        }
        let fnameUrl = NSURL(fileURLWithPath: sciDoc.uri)
        let fname = fnameUrl.lastPathComponent!
        self = CollaborationMessage.ReadingDocument(filename: fname, contentHash: cHash, paperTitle: sciDoc.title)
    }
    
    /// Creates a collaboration message from raw data (for example data that is received from network peers).
    init?(fromData: NSData) {
        // convert data to string and make sure there is at least one ':'
        guard let string = String(data: fromData, encoding: NSUTF8StringEncoding),
              r = string.rangeOfString(":") else {
            return nil
        }
        
        // split using :
        let prefix = string.substringToIndex(r.startIndex)
        let suffix = string.substringFromIndex(r.endIndex)
        
        guard let parsedPrefix = MessagePrefix(rawValue: prefix) else {
            AppSingleton.log.error("Failed to parse prefix: \(prefix)")
            return nil
        }
        
        switch parsedPrefix {
            
        case .reportIdle:
            self = ReportIdle
            
        case .requestStatus:
            self = RequestStatus
            
        case .trackingChange:
            self = TrackingChange(newState: (suffix as NSString).boolValue)
            
        case .readingDocument:
            // split filename, contenthash and title components
            let components = suffix.componentsSeparatedByString("::")
            guard components.count == 3 else {
                return nil
            }
            let fileName = components[0]
            let contentHash = components[1]
            var title: String?
            if !components[2].isEmpty {
                title = components[2]
            }
            self = ReadingDocument(filename: fileName, contentHash: contentHash, paperTitle: title)
            
        case .requestFile:
            self = RequestFile(contentHash: suffix)
            
        case .scrollTo:
            
            guard let area = FocusArea(fromString: suffix) else {
                AppSingleton.log.error("Could not convert string to focus area")
                return nil
            }
            
            self = ScrollTo(area: area)
            
        case .addReadingTag:
            
            guard let tag = ReadingTag(fromString: suffix, pdfBase: nil) else {
                AppSingleton.log.error("Failed to parse tag string")
                return nil
            }
            
            self = AddReadingTag(tag)
            
        case .removeReadingTag:
            
            guard let tag = ReadingTag(fromString: suffix, pdfBase: nil) else {
                AppSingleton.log.error("Failed to parse tag string")
                return nil
            }
            
            self = RemoveReadingTag(tag)
            
        case .readAreas:
            
            let inputAreas = suffix.componentsSeparatedByString(";")
            let parsedAreas = inputAreas.flatMap({FocusArea(fromString: $0)})
            guard parsedAreas.count > 0 else {
                AppSingleton.log.error("Failed to find any areas in input")
                return nil
            }
            self = ReadAreas(parsedAreas)
            
        }
    }
    
    /// Gets the string that identifies a message, for this collaboration message (does not include `:`).
    func prefix() -> String {
        switch self {
        case .ReportIdle:
            return MessagePrefix.reportIdle.rawValue
        case .RequestStatus:
            return MessagePrefix.requestStatus.rawValue
        case .TrackingChange:
            return MessagePrefix.trackingChange.rawValue
        case .ReadingDocument:
            return MessagePrefix.readingDocument.rawValue
        case .RequestFile:
            return MessagePrefix.requestFile.rawValue
        case .ScrollTo:
            return MessagePrefix.scrollTo.rawValue
        case .AddReadingTag:
            return MessagePrefix.addReadingTag.rawValue
        case .RemoveReadingTag:
            return MessagePrefix.removeReadingTag.rawValue
        case .ReadAreas:
            return MessagePrefix.readAreas.rawValue
        }
    }
    
    /// Generates a string from this collaboration message (so that it can be sent to peers).
    func buildMessage() -> String {
        switch self {
        case .ReportIdle:
            return self.prefix() + ":"
        case .RequestStatus:
            return self.prefix() + ":"
        case .TrackingChange(let newState):
            return self.prefix() + ":" + newState.description
        case .ReadingDocument(let filename, let contentHash, let paperTitle):
            return self.prefix() + ":" + filename + "::" + contentHash + "::" + (paperTitle ?? "")
        case .RequestFile(let contentHash):
            return self.prefix() + ":" + contentHash
        case .ScrollTo(let area):
            return self.prefix() + ":" + area.description
        case .AddReadingTag(let tag):
            return self.prefix() + ":" + tag.description
        case .RemoveReadingTag(let tag):
            return self.prefix() + ":" + tag.description
        case .ReadAreas(let areas):
            return self.prefix() + ":" + areas.map({$0.description}).joinWithSeparator(";")
        }
    }
    
    /// Sends itself to the given list of peers.
    /// Can set mode to unreliable if wanted (defaults to reliable).
    func sendTo(peers: [MCPeerID], _ mode: MCSessionSendDataMode = .Reliable) {
        let data = buildMessage().dataUsingEncoding(NSUTF8StringEncoding)!
        do {
            try Multipeer.session.sendData(data, toPeers: peers, withMode: mode)
        } catch {
            AppSingleton.log.error("Failed to send message '\(buildMessage())' to peers: \(error)")
        }
    }
    
    /// Sends itself to all connected peers.
    func sendToAll(mode: MCSessionSendDataMode = .Reliable) {
        let peers = Multipeer.session.connectedPeers
        guard peers.count > 0 else {
            return
        }
        sendTo(peers, mode)
    }
    
}
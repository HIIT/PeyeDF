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

import Cocoa
import MultipeerConnectivity
import os.log

private var pContext = 0

class PeerViewController: NSViewController {
    
    /// This inner enum defines what a peer is doing.
    enum PeerState {
        /// The peer is connected, but not reading
        case idle
        /// The peer is reading a document that we do not have open
        case reading(contentHash: String)
        /// The peer is reading a document that we have open
        case trackable(contentHash: String)
    }
    
    /// The current state for the peer represented by this view
    var currentState: PeerState = .idle { willSet {
        switch newValue {
        case .idle:
            DispatchQueue.main.async {
                self.fileLab.stringValue = "(connected)"
                self.titleLab.stringValue = ""
                self.readButton.isHidden = false
                self.readButton.isEnabled = true
                self.trackButton.isHidden = true
                self.trackButton.state = .off
            }
        case .reading:
            DispatchQueue.main.async {
                self.readButton.isHidden = false
                self.readButton.isEnabled = true
                self.trackButton.isHidden = true
                self.trackButton.state = .off
            }
        case .trackable:
            DispatchQueue.main.async {
                self.readButton.isHidden = true
                self.readButton.isEnabled = false
                self.trackButton.isHidden = false
                self.trackButton.state = .off
            }
        }
    } }
    
    /// Convenience accessor for the content hash which the peer is currently reading (nil if none)
    var currentHash: String? { get {
        switch currentState {
        case .trackable(let cHash):
            return cHash
        case .reading(let cHash):
            return cHash
        default:
            return nil
        }
    } }
    
    weak var fileProgress: Progress?
    
    @IBOutlet weak var peerImg: NSImageView!
    @IBOutlet weak var peerLab: NSTextField!
    @IBOutlet weak var fileLab: NSTextField!
    @IBOutlet weak var titleLab: NSTextField!
    @IBOutlet weak var progbar: NSProgressIndicator!
    @IBOutlet weak var readButton: NSButton!
    @IBOutlet weak var trackButton: NSButton!
    @IBOutlet weak var eyesLabel: NSTextField!
    
    /// Initializes this controller to be "owned" by a peer
    func setPeer(_ peer: MCPeerID) {
        readButton.tag = peer.hash
        trackButton.tag = peer.hash
        peerLab.stringValue = peer.displayName
    }
    
    /// Sets the paper that the peer is currently reading.
    /// (Only acts if it is different than the previous time this was called).
    func setPaperDetails(_ fname: String, cHash: String, title: String) {
        if currentHash == nil || currentHash! != cHash {
            DispatchQueue.main.async {
                self.fileLab.stringValue = fname
                self.titleLab.stringValue = title
            }
            // if we have a window open for the given cHash, set state to trackable, otherwise reading
            if Multipeer.ourWindows[cHash] != nil {
                currentState = .trackable(contentHash: cHash)
            } else {
                currentState = .reading(contentHash: cHash)
            }
        }
    }
    
    /// Pressing the track button causes a check to make sure we have a window open
    /// related to the content hash of this controller. It then changes the multipeer.track
    /// field (which will in turn change the state of this button).
    @IBAction func trackPress(_ sender: NSButton) {
        // make sure the current state is trackable, if so set values accordingly. If not, reset tracking and post an error.
        switch currentState {
        case .trackable(let cHash):
            if sender.state == .on {
                // get the peer corresponding to the senders' tag (we set the tag to the peer's hash)
                let peers = Multipeer.session.connectedPeers.filter({$0.hash == sender.tag})
                guard peers.count == 1 else {
                    return
                }
                let pHash = peers[0].hash
                Multipeer.tracked.peer = pHash
                Multipeer.tracked.cHash = cHash
            } else {
                Multipeer.tracked.peer = nil
                Multipeer.tracked.cHash = ""
            }
        default:
            // Track was pressed when we were not in the trackable state
            Multipeer.tracked.peer = nil
            Multipeer.tracked.cHash = ""
        }
    }
    
    @IBAction func readPress(_ sender: NSButton) {
        // get the peer corresponding to the senders' tag (we set the tag to the peer's hash)
        let peers = Multipeer.session.connectedPeers.filter({$0.hash == sender.tag})
        guard peers.count == 1 else {
            return
        }
        // make sure the current state is reading. If not, post an error and return.
        switch currentState {
        case .reading(let cHash):
            self.readButton.isEnabled = false
            // check if we have a file corresponding to the given content hash in dime (and open it). If not, request file to peer (will be opened once received)
            DiMeFetcher.retrieveUrl(for: SciDocConvertible.contentHash(cHash)) {
                foundUrl in
                if let url = foundUrl {
                    AppSingleton.appDelegate.openDocument(url)
                } else {
                    CollaborationMessage.requestFile(contentHash: cHash).sendTo(peers)
                }
                self.currentState = .trackable(contentHash: cHash)
            }
        default:
            if #available(OSX 10.12, *) {
                os_log("Read was pressed when we were not in the reading state", type: .error)
            }
        }
    }
    
    // MARK: - Receiving file and progress bar updates
    
    func startReceivingFile(_ progress: Progress) {
        fileProgress = progress
        fileProgress?.addObserver(self, forKeyPath: "fractionCompleted", options: .new, context: &pContext)
        DispatchQueue.main.async {
            self.progbar.isHidden = false
        }
    }
    
    func receiptComplete() {
        fileProgress?.removeObserver(self, forKeyPath: "fractionCompleted", context: &pContext)
        DispatchQueue.main.async {
            self.progbar.isHidden = true
        }
        fileProgress = nil
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &pContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        DispatchQueue.main.async {
            self.progbar.doubleValue = change![NSKeyValueChangeKey.newKey]! as! Double
        }
    }
    
}

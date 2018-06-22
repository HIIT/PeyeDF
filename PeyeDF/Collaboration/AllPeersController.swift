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

class AllPeersController: NSViewController {
    
    /// Keeps track of all connected peers (using their hash as key), so that each has its own view
    fileprivate var connectedPeers = [Int: PeerViewController]()
    
    @IBOutlet weak var stackView: AnimatedStack!
    
    func addPeer(_ peer: MCPeerID) {
        DispatchQueue.main.async {
            let vc = AppSingleton.collaborationStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("PeerViewController")) as! PeerViewController
            self.stackView.animateViewIn(vc.view)
            vc.setPeer(peer)
            self.connectedPeers[peer.hash] = vc
        }
    }
    
    /// Remove a peer from the view controller (e.g. when connection is lost)
    func removePeer(_ peer: MCPeerID) {
        guard let vc = connectedPeers[peer.hash] else {
            return
        }
        DispatchQueue.main.async {
            self.stackView.animateViewOut(vc.view)
        }
        connectedPeers.removeValue(forKey: peer.hash)
    }
    
    func setPaperDetails(_ forPeer: MCPeerID, fname: String, cHash: String, title: String?) {
        guard let vc = connectedPeers[forPeer.hash] else {
            return
        }
        vc.setPaperDetails(fname, cHash: cHash, title: title ?? "")
    }
    
    /// Show / hide peer eyes telling us that they are tracking us
    func setTrackingState(_ newState: Bool, forPeer: MCPeerID) {
        guard let vc = connectedPeers[forPeer.hash] else {
            return
        }
        DispatchQueue.main.async {
            vc.eyesLabel.isHidden = !newState
        }
    }
    
    /// Tells us the latest content hash that a peer told us they are reading (nil if none)
    func getCurrentContentHash(forPeer peer: MCPeerID) -> String? {
        guard let vc = connectedPeers[peer.hash] else {
            return nil
        }
        return vc.currentHash
    }
    
    /// Reset current status for a peer to "(connected)"
    func setIdle(_ peer: MCPeerID) {
        guard let vc = connectedPeers[peer.hash] else {
            return
        }
        vc.currentState = .idle
    }
    
    /// Resets button state (loses the fact that we started reading the same paper as they)
    /// for a given content hash
    func resetState(_ forContentHash: String) {
        connectedPeers.forEach() {
            if let theirHash = $0.1.currentHash , theirHash == forContentHash {
                $0.1.currentState = .reading(contentHash: theirHash)
            }
        }
    }
    
    /// Allows us to track all peers that were reading the document corresponding to
    /// a given content hash
    func checkIfTrackable(_ contentHash: String) {
        connectedPeers.forEach() {
            if let theirHash = $0.1.currentHash , theirHash == contentHash {
                $0.1.currentState = .trackable(contentHash: theirHash)
            }
        }
    }
    
    func startDownload(_ forPeer: MCPeerID, progress: Progress) {
        guard let vc = connectedPeers[forPeer.hash] else {
            return
        }
        vc.startReceivingFile(progress)
    }
    
    func endDownload(_ forPeer: MCPeerID) {
        guard let vc = connectedPeers[forPeer.hash] else {
            return
        }
        vc.receiptComplete()
    }
    
    /// Acknowledges what we want to track.
    /// If the contenthash + peer hash tuple matches one of our view controllers,
    /// sets the track state of that peer controller to on.
    func trackUpdate(_ newTuple: (peer: Int?, cHash: String?)) {
        connectedPeers.forEach() {
            ph, vc in
            if let newP = newTuple.peer, let newCH = newTuple.cHash, let theirCurrentHash = vc.currentHash ,
              newP == ph && newCH == theirCurrentHash {
                DispatchQueue.main.async {
                    vc.trackButton.state = .on
                }
            } else {
                DispatchQueue.main.async {
                    vc.trackButton.state = .off
                }
            }
        }
    }
    
    /// Called when the user wants to disconnect
    @IBAction func disconnectPress(_ sender: NSButton) {
        // remove all views within the stack and then disconnect
        for tuple in connectedPeers {
            DispatchQueue.main.async {
                self.stackView.animateViewOut(tuple.1.view)
            }
            connectedPeers.removeValue(forKey: tuple.0)
        }
        Multipeer.session.disconnect()
        
        // force no tracked peer
        Multipeer.tracked.peer = nil
    }
}

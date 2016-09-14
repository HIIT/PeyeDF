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

/// Singleton class used to share multipeer connectivity information / UI
class Multipeer: NSObject {
    
    // MARK: - Useful globals
    
    /// Shared instance used to implement MCBrowserViewControllerDelegate
    static var sharedInstance = Multipeer()
    
    /// Shared delegate object which responds to all network events
    static var delegate = SessionDelegate()

    /// Peer id user for this machine on the network
    static var peerId: MCPeerID = {
        // check if a peerid is present in nsuser defaults. If yes, and it has the same display name
        // as the one set for the dime user preference, use that.
        let peer: MCPeerID
        let name = UserDefaults.standard.value(forKey: PeyeConstants.prefDiMeServerUserName) as! String
        if let storedPeerData = UserDefaults.standard.value(forKey: MPConstants.peerIdKey) as? Data,
          let storedPeer = NSKeyedUnarchiver.unarchiveObject(with: storedPeerData) as? MCPeerID ,
          storedPeer.displayName == name {
            // we have a stored peer, and its name matches ours
            peer = storedPeer
        } else {
            // create a new peer
            peer = MCPeerID(displayName: name)
        }
        // save generated peer in user defaults
        let peerData = NSKeyedArchiver.archivedData(withRootObject: peer)
        UserDefaults.standard.setValue(peerData, forKey: MPConstants.peerIdKey)
        UserDefaults.standard.synchronize()
        return peer
    }()
    
    /// Multipeer connectivity session
    static var session: MCSession = {
        let ses = MCSession(peer: Multipeer.peerId)
        ses.delegate = Multipeer.delegate
        return ses
    }()
    
    /// Browser view controller
    static var browserController: MCBrowserViewController = {
        let vc = MCBrowserViewController(serviceType: MPConstants.serviceType, session: Multipeer.session)
        vc.delegate = Multipeer.sharedInstance
        vc.maximumNumberOfPeers = 1
        return vc
    }()
    
    /// Browser window
    static var browserWindow: SecondaryWindow = {
        let window = SecondaryWindow(contentViewController: Multipeer.browserController)
        window.title = "Connect to peer"
        window.isReleasedWhenClosed = false
        return window
    }()
    
    /// Advertiser assistant
    static var advertiser: MCAdvertiserAssistant = {
        let adv = MCAdvertiserAssistant(serviceType: MPConstants.serviceType, discoveryInfo: nil, session: session)
        return adv
    }()
    
    /// Peer window, showing list of all peers we are connected to (normally, one)
    static var peerWindow: NSWindowController = {
        let win = AppSingleton.collaborationStoryboard.instantiateController(withIdentifier: "AllPeersWindowController")
        return win as! NSWindowController
    }()
    
    /// Convenience field to get the all peers controller
    static var peerController: AllPeersController { get {
        return Multipeer.peerWindow.contentViewController! as! AllPeersController
    } }
    
    // MARK: - Reading / Tracking
    
    /// The hash of the peer being tracked and the associated content hash (document).
    /// This value is central to tracking since every time we receive a CollaborationMessage
    /// we check what we are tracking so that the view is tracked accordingly.
    /// If either is nil, we are tracking nothing.
    /// When this value is changed, it is propagated to the all peers controller
    /// so that the "track" checkbox is set to on / off accordingly.
    static var tracked: (peer: Int?, cHash: String?) = (nil, nil) { willSet {
        Multipeer.peerController.trackUpdate(newValue)  // update tracked peer
        // tell previously tracked peer that we stopped tracking them
        if let pHash = tracked.peer {
            CollaborationMessage.trackingChange(newState: false).sendTo(Multipeer.session.connectedPeers.filter({$0.hash == pHash}))
        }
        // tell tracked peer that we started tracking them
        if let pHash = newValue.peer {
            CollaborationMessage.trackingChange(newState: true).sendTo(Multipeer.session.connectedPeers.filter({$0.hash == pHash}))
        }
    } }
    
    /// Relates a content hash to one open window (file open on our side).
    static var ourWindows = [String: DocumentWindowController]() { didSet {
        // if we are connected to someone, adjusts the view controller(s) accordingly
        if Multipeer.session.connectedPeers.count > 0 {
            let removed = oldValue.keys.filter({!ourWindows.keys.contains($0)})
            // if a window that contained the document we want to track is closed,
            // undo tracking
            if let tHash = tracked.cHash , removed.contains(tHash) {
                tracked.cHash = nil
            }
            // reset state for peers that were reading the document that we closed
            removed.forEach() {
                peerController.resetState($0)
                removeOverviewController(forContentHash: $0)
            }
            // for new windows, allow us to immediately track the corresponding peer
            let added = ourWindows.keys.filter({!oldValue.keys.contains($0)})
            added.forEach() {
                peerController.checkIfTrackable($0)
                makeOverviewController(forContentHash: $0)
            }
        }
    } }
    
    // MARK: - Peer overview
    
    /// Maps a contenthash to a peer overview (to see what the outcome of collaboration for that document).
    /// One entry per document / window.
    static var overviewControllers = [String: PeerOverviewController]()
    
    /// Check if a peer overview controller exists and creates it and its window, if needed (otherwise does nothing).
    static func makeOverviewController(forContentHash cHash: String) {
        guard overviewControllers[cHash] == nil && ourWindows[cHash] != nil else {
            return
        }
        
        let newController = AppSingleton.collaborationStoryboard.instantiateController(withIdentifier: "PeerOverviewController") as! PeerOverviewController
        overviewControllers[cHash] = newController
        
        DispatchQueue.main.async {
            let win = SecondaryWindow(contentViewController: newController)
            win.isReleasedWhenClosed = false
            win.orderFront(Multipeer.sharedInstance)
            newController.win = win  // create strong ref to keep window in memory
            newController.pdfOverview.pdfDetail = self.ourWindows[cHash]?.pdfReader
            win.title = self.ourWindows[cHash]?.window?.title ?? "Overview"
        }
    }
    
    /// Removes a peer overview controller and related window (if they exist, otherwise does nothing).
    static func removeOverviewController(forContentHash cHash: String) {
        guard overviewControllers[cHash] != nil else {
            return
        }
        
        let removedController = overviewControllers.removeValue(forKey: cHash)
        DispatchQueue.main.async {
            removedController?.pdfOverview.pdfDetail = nil
            removedController?.pdfOverview = nil
            removedController?.win.close()
            removedController?.win = nil  // manually release window by removing strong ref
        }
    }
}

/// Implementation of delegate to respond to button presses on view controller
extension Multipeer: MCBrowserViewControllerDelegate {
    @objc func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        Multipeer.browserWindow.close()
    }
    
    @objc func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        Multipeer.browserWindow.close()
    }
}

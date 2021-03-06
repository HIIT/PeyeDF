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

/// This class receives and reroutes all multipeer messages to other parts of the application
@objc class SessionDelegate: NSObject, MCSessionDelegate {
    
    /// Received some data. Converts it to CollaborationMessage and dispatches it where needed.
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let cmsg = CollaborationMessage(fromData: data) else {
            return
        }
        switch cmsg {
            
        case .reportIdle:
            Multipeer.peerController.setIdle(peerID)
            
        case .requestStatus:
            sendStatus(peerID)
            
        case .trackingChange(let newState):
            // update global
            if newState {
                Multipeer.trackers.insert(peerID)
            } else {
                Multipeer.trackers.remove(peerID)
            }
            // if the peer that started tracking us is the one we are tracking, stop tracking that peer
            if let pHash = Multipeer.tracked.peer , pHash == peerID.hash {
                Multipeer.tracked.peer = nil
            }
            // show / hide eyes of that peer in peer controller
            Multipeer.peerController.setTrackingState(newState, forPeer: peerID)
            // if that peer started tracking us, send them all our tags
            if newState {
                if let theirHash = Multipeer.peerController.getCurrentContentHash(forPeer: peerID),
                   let wc = Multipeer.ourWindows[theirHash], let sciDoc = wc.pdfReader?.sciDoc {
                    let ourReadingTags = sciDoc.tags.compactMap({$0 as? ReadingTag})
                    ourReadingTags.forEach() {
                        CollaborationMessage.addReadingTag($0).sendTo([peerID])
                    }
                }
            }
            
        case .readingDocument(let fname, let cHash, let title):
            // a peer told us that they are reading a document, update their view controller
            Multipeer.peerController.setPaperDetails(peerID, fname: fname, cHash: cHash, title: title)
            // create an overview controller to collaborate on this document (if needed)
            Multipeer.makeOverviewController(forContentHash: cHash)
            // if the tracked content hash is different than this one, stop tracking
            if let trackedHash = Multipeer.tracked.cHash, trackedHash != cHash {
                Multipeer.tracked.cHash = nil
            }
            
        case .requestFile(let cHash):
            // we received a request for current file, send it to sender.
            DiMeFetcher.retrieveUrl(for: SciDocConvertible.contentHash(cHash)) {
                foundUrl in
                
                guard let url = foundUrl else {
                    return
                }
                
                // (arbitrary) name of resource is filename without extension
                let rname = url.deletingPathExtension().lastPathComponent
                    
                Multipeer.session.sendResource(at: url, withName: rname, toPeer: peerID, withCompletionHandler: nil)
            }
            
        case .scrollTo(let area):
            // check that we are tracking this peer, and we have a window open for the given peers' content hash
            guard let pHash = Multipeer.tracked.peer, let cHash = Multipeer.tracked.cHash , pHash == peerID.hash else {
                return
            }
            
            guard let win = Multipeer.ourWindows[cHash] else {
                return
            }
            
            win.pdfReader?.focusOn(area, delay: 0)
            
        case .addReadingTag(let tag):
            
            // check that we have a window open for the given peer's content hash
            guard let cHash = Multipeer.peerController.getCurrentContentHash(forPeer: peerID) else {
                return
            }
            
            guard let win = Multipeer.ourWindows[cHash], let sciDoc = win.pdfReader?.sciDoc else {
                return
            }
            
            sciDoc.addTag(tag)
            
        case .removeReadingTag(let tag):
            
            // check that we have a window open for the given peers' content hash
            guard let cHash = Multipeer.peerController.getCurrentContentHash(forPeer: peerID) else {
                return
            }
            
            guard let win = Multipeer.ourWindows[cHash], let sciDoc = win.pdfReader?.sciDoc else {
                return
            }
            
            sciDoc.subtractTag(tag)
            
        case .seenAreas(let areas):
            // check that we are tracking this peer, and we have a window open for the given peer's content hash
            guard let cHash = Multipeer.peerController.getCurrentContentHash(forPeer: peerID) else {
                return
            }
            
            guard let win = Multipeer.ourWindows[cHash], let pdfReader = win.pdfReader else {
                return
            }
            
            // add each area to the overview
            areas.forEach() {
                Multipeer.overviewControllers[cHash]?.pdfOverview.addArea($0, fromSource: .networkPeer)
            }
            
            // display the last area directly on the pdf
            if let area = areas.last {
                switch area.type {
                case .rect, .circle:
                    pdfReader.highlight = area
                default:
                    if #available(OSX 10.12, *) {
                        os_log("Displaying read areas other than rects or circles is not implemented", type: .error)
                    }
                }
            }
            
        case .markRects(let rects):
            // check that we are tracking this peer, and we have a window open for the given peer's content hash
            guard let cHash = Multipeer.peerController.getCurrentContentHash(forPeer: peerID) else {
                return
            }
            
            guard let win = Multipeer.ourWindows[cHash], let pdfReader = win.pdfReader else {
                return
            }
            
            pdfReader.selectionMarkAndAnnotate(rects)
            
        case .fixation(let area):
            // check that we are tracking this peer, and we have a window open for the given peers' content hash
            guard let pHash = Multipeer.tracked.peer, let cHash = Multipeer.tracked.cHash , pHash == peerID.hash else {
                return
            }
            
            guard let win = Multipeer.ourWindows[cHash],
                  let point = win.pdfReader?.pointInView(fromArea: area) else {
                return
            }
            
            win.readerDelegate?.displayPeerFixation(pointInView: point)

        case .undo:
            // check that we are tracking this peer, and we have a window open for the given peers' content hash
            guard let pHash = Multipeer.tracked.peer, let cHash = Multipeer.tracked.cHash , pHash == peerID.hash else {
                return
            }
            
            guard let win = Multipeer.ourWindows[cHash], let pdfReader = win.pdfReader else {
                    return
            }
            
            DispatchQueue.main.async {
                pdfReader.undoManager?.undo()
            }
            
        case .redo:
            // check that we are tracking this peer, and we have a window open for the given peers' content hash
            guard let pHash = Multipeer.tracked.peer, let cHash = Multipeer.tracked.cHash , pHash == peerID.hash else {
                return
            }
            
            guard let win = Multipeer.ourWindows[cHash], let pdfReader = win.pdfReader else {
                return
            }
            
            DispatchQueue.main.async {
                pdfReader.undoManager?.redo()
            }
            
        }
    }
    
    /// When a new peer is successfully connected, adds its view to the peer window.
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            DispatchQueue.main.async {
                Multipeer.peerWindow.showWindow(self)
                Multipeer.peerController.addPeer(peerID)
            }
            // after 1 second, send our status and request their status
            let queue = DispatchQueue.global(qos: DispatchQoS.QoSClass.default)
            queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1.0 * Float(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
                self.sendStatus(peerID)
                CollaborationMessage.requestStatus.sendTo([peerID])
            }
        case .connecting:
            break
        case .notConnected:
            Multipeer.peerController.removePeer(peerID)
            // check if this peer is the one being tracked. if so, set it to nil.
            if let pHash = Multipeer.tracked.peer , pHash == peerID.hash {
                Multipeer.tracked.peer = nil
            }
        @unknown default:
            break
        }
    }
    
    /// Starts to receive a pdf document. Updates the peer window to show progress.
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        Multipeer.peerController.startDownload(peerID, progress: progress)
    }
    
    /// Pdf document is received. Hides the progress bar and opens the document.
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        Multipeer.peerController.endDownload(peerID)
        if let error = error {
            AppSingleton.alertUser("Error while transferring file.", infoText: "\(error)")
            return
        }
        guard let localURL = localURL else {
            AppSingleton.alertUser("Could not get local url.")
            return
        }
        // resource name is without pdf, append .pdf to it
        let newname = resourceName + ".pdf"
        let baseUrl = localURL.deletingLastPathComponent()
        let newUrl = baseUrl.appendingPathComponent(newname)
        // if file does not exists already, rename received resource
        if !FileManager.default.fileExists(atPath: (newUrl.path)) {
            do {
                try FileManager.default.moveItem(atPath: (localURL.path), toPath: (newUrl.path))
            } catch {
                AppSingleton.alertUser("Failed to rename received file.", infoText: "\(error)")
                return
            }
        }
        AppSingleton.appDelegate.openDocument(newUrl)
    }
    
    /// Receives a stream. Not used.
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        if #available(OSX 10.12, *) {
            os_log("Multipeer framework receiving a stream: -- not implemented --", type: .error)
        }
        return
    }
    
    /// Convenience function to send our current status to a given peer
    fileprivate func sendStatus(_ peer: MCPeerID) {
        // get the scidoc from the current main window, if main window is documentwindowcontroller
        if let docWindow = NSApplication.shared.mainWindow?.windowController as? DocumentWindowController,
          let pdfReader = docWindow.pdfReader {
            CollaborationMessage(readingDocumentFromSciDoc: pdfReader.sciDoc)?.sendTo([peer])
        }
    }
    
}

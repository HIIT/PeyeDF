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

/// This class receives and reroutes all multipeer messages to other parts of the application
@objc class SessionDelegate: NSObject, MCSessionDelegate {
    
    /// Received some data. Converts it to CollaborationMessage and dispatches it where needed.
    func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
        guard let cmsg = CollaborationMessage(fromData: data) else {
            return
        }
        switch cmsg {
            
        case .ReportIdle:
            Multipeer.peerController.setIdle(peerID)
            
        case .RequestStatus:
            sendStatus(peerID)
            
        case .TrackingChange(let newState):
            // if the peer that started tracking us is the one we are tracking, stop tracking that peer
            if let pHash = Multipeer.tracked.peer where pHash == peerID.hash {
                Multipeer.tracked.peer = nil
            }
            // show / hide eyes of that peer in peer controller
            Multipeer.peerController.setTrackingState(newState, forPeer: peerID)
            // if that peer started tracking us, send them all our tags
            if newState {
                if let theirHash = Multipeer.peerController.getCurrentContentHash(forPeer: peerID),
                   let wc = Multipeer.ourWindows[theirHash], let sciDoc = wc.pdfReader?.sciDoc {
                    let ourReadingTags = sciDoc.tags.flatMap({$0 as? ReadingTag})
                    ourReadingTags.forEach() {
                        CollaborationMessage.AddReadingTag($0).sendTo([peerID])
                    }
                }
            }
            
        case .ReadingDocument(let fname, let cHash, let title):
            // a peer told us that they are reading a document, update their view controller
            Multipeer.peerController.setPaperDetails(peerID, fname: fname, cHash: cHash, title: title)
            // create an overview controller to collaborate on this document (if needed)
            Multipeer.makeOverviewController(forContentHash: cHash)
            
        case .RequestFile(let cHash):
            // we received a request for current file, send it to sender.
            DiMeFetcher.retrieveUrl(forContentHash: cHash) {
                foundUrl in
                
                guard let url = foundUrl else {
                    AppSingleton.log.error("We received a request for a contenthash referring to a file that we do not have.")
                    return
                }
                
                // (arbitrary) name of resource is filename without extension (minus last 4 characters)
                let rname = url.lastPathComponent!.substringToIndex(url.lastPathComponent!.endIndex.advancedBy(-4))
                    
                Multipeer.session.sendResourceAtURL(url, withName: rname, toPeer: peerID, withCompletionHandler: nil)
            }
            
        case .ScrollTo(let area):
            // check that we are tracking this peer, and we have a window open for the given peers' content hash
            guard let pHash = Multipeer.tracked.peer, cHash = Multipeer.tracked.cHash where pHash == peerID.hash else {
                return
            }
            
            guard let win = Multipeer.ourWindows[cHash] else {
                return
            }
            
            win.pdfReader?.focusOn(area, delay: 0, offset: false)
            
        case .AddReadingTag(let tag):
            
            // check that we have a window open for the given peer's content hash
            guard let cHash = Multipeer.peerController.getCurrentContentHash(forPeer: peerID) else {
                return
            }
            
            guard let win = Multipeer.ourWindows[cHash], sciDoc = win.pdfReader?.sciDoc else {
                return
            }
            
            sciDoc.addTag(tag)
            
        case .RemoveReadingTag(let tag):
            
            // check that we have a window open for the given peers' content hash
            guard let cHash = Multipeer.peerController.getCurrentContentHash(forPeer: peerID) else {
                return
            }
            
            guard let win = Multipeer.ourWindows[cHash], sciDoc = win.pdfReader?.sciDoc else {
                return
            }
            
            sciDoc.subtractTag(tag)
            
        case .ReadAreas(let areas):
            // check that we are tracking this peer, and we have a window open for the given peer's content hash
            guard let cHash = Multipeer.peerController.getCurrentContentHash(forPeer: peerID) else {
                return
            }
            
            guard let win = Multipeer.ourWindows[cHash], pdfReader = win.pdfReader else {
                return
            }
            
            // add each area to the overview
            areas.forEach() {
                Multipeer.overviewControllers[cHash]?.pdfOverview.addAreaForPeer($0)
            }
            
            // display the last area directly on the pdf
            if let area = areas.last {
                switch area.type {
                case .Rect(let rect):
                    let highlightRect = (pageIndex: area.pageIndex, rect: rect)
                    pdfReader.highlightRect = highlightRect
                default:
                    AppSingleton.log.error("Displaying read areas other than rects is not implemented")
                }
            }
        }
    }
    
    /// When a new peer is successfully connected, adds its view to the peer window.
    func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
        switch state {
        case .Connected:
            dispatch_async(dispatch_get_main_queue()) {
                Multipeer.peerWindow.showWindow(self)
                Multipeer.peerController.addPeer(peerID)
            }
            // after 1 second, send our status and request their status
            let queue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1.0 * Float(NSEC_PER_SEC))), queue) {
                self.sendStatus(peerID)
                CollaborationMessage.RequestStatus.sendTo([peerID])
            }
        case .Connecting:
            break
        case .NotConnected:
            Multipeer.peerController.removePeer(peerID)
            // check if this peer is the one being tracked. if so, set it to nil.
            if let pHash = Multipeer.tracked.peer where pHash == peerID.hash {
                Multipeer.tracked.peer = nil
            }
        }
    }
    
    /// Starts to receive a pdf document. Updates the peer window to show progress.
    func session(session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, withProgress progress: NSProgress) {
        Multipeer.peerController.startDownload(peerID, progress: progress)
    }
    
    /// Pdf document is received. Hides the progress bar and opens the document.
    func session(session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, atURL localURL: NSURL, withError error: NSError?) {
        Multipeer.peerController.endDownload(peerID)
        if let error = error {
            AppSingleton.alertUser("Error while transferring file.", infoText: "\(error)")
            return
        }
        // resource name is without pdf, append .pdf to it
        let newname = resourceName + ".pdf"
        let baseUrl = localURL.URLByDeletingLastPathComponent!
        let newUrl = baseUrl.URLByAppendingPathComponent(newname)
        // if file does not exists already, rename received resource
        if !NSFileManager.defaultManager().fileExistsAtPath(newUrl.path!) {
            do {
                try NSFileManager.defaultManager().moveItemAtPath(localURL.path!, toPath: newUrl.path!)
            } catch {
                AppSingleton.alertUser("Failed to rename received file.", infoText: "\(error)")
                return
            }
        }
        (NSApplication.sharedApplication().delegate! as! AppDelegate).openDocument(newUrl, searchString: nil)
    }
    
    /// Receives a stream. Not used.
    func session(session: MCSession, didReceiveStream stream: NSInputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        AppSingleton.log.error("Multipeer framework receiving a stream: -- not implemented --")
        return
    }
    
    /// Convenience function to send our current status to a given peer
    private func sendStatus(peer: MCPeerID) {
        // get the scidoc from the current main window, if main window is documentwindowcontroller
        if let docWindow = NSApplication.sharedApplication().mainWindow?.windowController as? DocumentWindowController,
          pdfReader = docWindow.pdfReader {
            CollaborationMessage(readingDocumentFromSciDoc: pdfReader.sciDoc)?.sendTo([peer])
        }
    }
    
}

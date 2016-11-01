//
//  ViewController.swift
//  LSLSwiftExample
//
//  Created by Marco Filetti on 07/10/2016.
//  Copyright © 2016 Aalto University. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    // NOTE: -------
    //
    // The lsl_api.cfg must contain the IP(s) of the streams we are trying to connect to.
    // See https://github.com/sccn/labstreaminglayer/wiki/NetworkConnectivity.wiki
    //
    // -------------

    @IBOutlet weak var textField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Display "Loading..." until we have a response
        textField.stringValue = "Loading..."
        
        DispatchQueue.global(qos: .default).async {
        
            var inf: lsl_streaminfo? = nil
            
            var description = "No streams found\n(Remember to edit lsl_api.cfg in project)"
            
            // Spend 3 seconds trying to fill a buffer of size 1024
//            let found = lsl_resolve_all(&inf, 1024, 3)
//            let found = lsl_resolve_byprop(&inf, 1, UnsafeMutablePointer<Int8>(mutating: ("name" as NSString).utf8String), UnsafeMutablePointer<Int8>(mutating: ("SMI_Event" as NSString).utf8String), 1, 3)
            let found = lsl_resolve_byprop(&inf, 1, UnsafeMutablePointer<Int8>(mutating: ("name" as NSString).utf8String), UnsafeMutablePointer<Int8>(mutating: ("SMI_Event" as NSString).utf8String), 1, 3)
            Swift.print(found)
            
            if inf != nil {
                
                // With a buffer of 6 minutes of data, fill inlet
                let inlet = lsl_create_inlet(inf, 360, LSL_NO_PREFERENCE, 1)
                
                // Retrieve full information from stream (required)
                let fullinfo = lsl_get_fullinfo(inlet, LSL_FOREVER, nil)
                
                // Put information in the `xml` pointer
                let xml = lsl_get_xml(fullinfo)
                
                let parsed = XMLParser(data: String(utf8String: xml!)!.data(using: .utf8)!)
                let parsDelegate = LSLXMLParserDelegate()
                parsed.delegate = parsDelegate
                parsed.parse()
                
                // Convert pointer to Swift String
                description = String(utf8String: xml!)!
                
                let ii = lsl_create_inlet(inf!, 1024, LSL_NO_PREFERENCE, 1)
                var errcode: Int32 = 0
                lsl_open_stream(ii, 30, &errcode)
                if errcode != 0 {
                    fatalError("Errcode is: \(errcode)")
                }
                DispatchQueue.global(qos: .background).async {
                    let channelIndex = parsDelegate.channelIndexes["positionX"]!
                    for _ in 0..<10000000 {
                        var buf: [Float] = [0, 0, 0, 0, 0, 0]
                        let timestamp = lsl_pull_sample_f(ii, &buf, Int32(buf.count), 5, &errcode)
                        Swift.print("x pos is \(buf[channelIndex])")
                    }
                }
                
                
            }
            
            // Show response in window (on main queue, since we update the UI)
            DispatchQueue.main.async {
                self.textField.stringValue = description
            }
            
        }
    }
    
}


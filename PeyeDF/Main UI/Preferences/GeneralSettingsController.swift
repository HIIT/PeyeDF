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
import Cocoa

class GeneralSettingsController: NSViewController {
    
    var blockStrings: [String] = {
        return UserDefaults.standard.value(forKey: PeyeConstants.prefStringBlockList) as! [String]
    }()
    
    @IBOutlet weak var downloadMetadataCell: NSButtonCell!
    @IBOutlet weak var checkForUpdatesCell: NSButtonCell!
    
    @IBOutlet weak var blockStringTable: NSTableView!
    @IBOutlet var blockStringController: NSArrayController!
    
    @IBOutlet weak var textField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let options: [String: AnyObject] = ["NSContinuouslyUpdatesValue": true as AnyObject]
        
        downloadMetadataCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefDownloadMetadata, options: options)
        checkForUpdatesCell.bind("value", to: NSUserDefaultsController.shared(), withKeyPath: "values." + PeyeConstants.prefCheckForUpdatesOnStartup, options: options)
    }
    
    @IBAction func Editeditem(_ sender: NSTextFieldCell) {
        guard blockStringTable.selectedRow > 0 else {
            return
        }
        
        blockStrings[blockStringTable.selectedRow] = sender.stringValue
        UserDefaults.standard.setValue(blockStrings, forKey: PeyeConstants.prefStringBlockList)
    }
    
    @IBAction func removePress(_ sender: AnyObject) {
        guard blockStringTable.selectedRow >= 0 else {
            return
        }
        
        DispatchQueue.main.async {
            self.blockStringController.remove(atArrangedObjectIndex: self.blockStringTable.selectedRow)
            self.blockStringTable.reloadData()
            UserDefaults.standard.setValue(self.blockStrings, forKey: PeyeConstants.prefStringBlockList)
        }
    }
    
    @IBAction func addPress(_ sender: NSButton) {
        guard textField.stringValue.trimmed().characters.count > 0 else {
            return
        }
        
        guard !blockStrings.contains(textField.stringValue) else {
            return
        }
        
        UserDefaults.standard.setValue(blockStrings, forKey: PeyeConstants.prefStringBlockList)
        DispatchQueue.main.async {
            self.blockStringController.addObject(self.textField.stringValue)
            self.blockStringTable.reloadData()
            self.textField.stringValue = ""
            UserDefaults.standard.setValue(self.blockStrings, forKey: PeyeConstants.prefStringBlockList)
            if self.blockStringTable.numberOfRows > 2 {
                self.blockStringTable.scrollRowToVisible(self.blockStringTable.numberOfRows - 1)
            }
        }
    }
}

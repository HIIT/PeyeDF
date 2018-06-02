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
import Cocoa

class TagConstants {
    
    /// Default color for tagged text
    static let annotationColourTagged: NSColor = NSColor(red: 0.84, green: 0.51, blue: 1, alpha: 0.35)
    
    /// Default color for tagged and selected text
    static let annotationColourTaggedSelected: NSColor = NSColor(red: 0.94, green: 0.31, blue: 1, alpha: 0.55)
    
    /// Default colour for tag title background
    static let annotationColourTagLabelBackground = NSColor(red: 0.96, green: 0.77, blue: 0.99, alpha: 1)
    
    /// Default font for tag title
    static let tagLabelFont = NSFont(name: "Marker Felt", size: 10)
    
    /// Padding between tag label (vertical)
    static let tagLabelPadding: CGFloat = 2
    
    /// Amount of tags stored in user defaults (for auto completion)
    static let nOfSavedTags = 25
    
    /// Name of user defaults identifying saved tags
    static let defaultsSavedTags = "defaults.savedTags"
    
    /// String used to identify searches for tags
    static let tagSearchPrefix = "#tag:"
    
    /// Tag value for tag menu item
    static let tagMenuTag = UInt(194851)
    
    // MARK: - Notifications
    
    /// String used to idenfity the notification related to changes in an object's tags (the notification's
    /// object.)
    ///
    /// **UserInfo dictionary fields**:
    /// - "newTags": The updated list of tags
    static let tagsChangedNotification = "hiit.PeyeDF.tagsChanged"
    
    /// String used to identify the notification sent when a tag search match within a document is found.
    /// The notification's object is a PDFBase.
    ///
    /// **UserInfo dictionary fields**:
    /// - "MyPDFTagFoundSelection": The selection corresponding to the text referenced by this tag.
    static let tagStringFoundNotification = "hiit.PeyeDF.tagStringFound"
    
}
    

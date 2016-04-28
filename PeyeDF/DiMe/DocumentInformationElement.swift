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

class DocumentInformationElement: DiMeBase {
    
    var uri: String
    var title: String?
    let plainTextContent: String?
    let appId: String
    var id: Int?
    let contentHash: String?
    private(set) var tags = [Tag]()
    
    /// Get only strings, only for simple tags
    var tagStrings: [String] { get {
        return tags.filter({($0 as Tag).dynamicType == Tag.self}).map({$0.text})
    } }
    
    /// Creates this information element. The id is set to the hash of the plaintext, or hash of uri if no text was found.
    ///
    /// - parameter uri: Path on file or web
    /// - parameter plainTextContent: Contents of whole file
    /// - parameter title: Title of the PDF
    init(uri: String, plainTextContent: String?, title: String?) {
        self.uri = uri
        self.plainTextContent = plainTextContent
        self.title = title
        
        if let ptc = plainTextContent {
            self.appId = "PeyeDF_\(ptc.sha1())"
            self.contentHash = ptc.sha1()
        } else {
            self.appId = "PeyeDF_\(uri.sha1())"
            self.contentHash = nil
        }
        
        super.init()
        
    }
    
    /// Returns a dime-compatible dictionary for this information element
    /// Sublasses must call this before editing their dictionary.
    override func getDict() -> [String : AnyObject] {
        theDictionary["uri"] = "file://" + uri
        theDictionary["appId"] = self.appId
        if let ptc = plainTextContent {
            theDictionary["plainTextContent"] = ptc
        }
        if let cHash = contentHash {
            theDictionary["contentHash"] = cHash
        }
        if let title = title {
            theDictionary["title"] = title
        }
        theDictionary["mimeType"] = "application/pdf"  // forcing pdf for mime type
        if tags.count > 0 {
            theDictionary["tags"] = tags.asDictArray()
        }
        
        // dime-required
        theDictionary["@type"] = "Document"
        theDictionary["type"] = "http://www.hiit.fi/ontologies/dime/#ScientificDocument"
        theDictionary["isStoredAs"] = "http://www.semanticdesktop.org/ontologies/2007/03/22/nfo/#LocalFileDataObject"
        
        return theDictionary
    }
    
    /// Creates information element from json
    init(fromDime json: JSON) {
        self.uri = json["uri"].stringValue.skipPrefix(7) // skip file:// prefix when importing
        self.title = json["title"].string
        self.id = json["id"].intValue
        self.plainTextContent = json["plainTextContent"].string
        self.appId = json["appId"].stringValue
        self.contentHash = json["contentHash"].string
        if let _tags = json["tags"].array {
            tags = _tags.flatMap({makeTag(fromJson: $0)})
        }
    }
    
    /// Returns app id using own dictionary
    func getAppId() -> String {
        return theDictionary["appId"]! as! String
    }
    
    /// Adds a tag to the information element. Posts a tags changed notification on success.
    /// - Attention: automatically tells DiMe to also perform this operation and uses its response to set own tags
    func addTag(tag: Tag) {
        if !tags.contains(tag) {
            if HistoryManager.sharedManager.dimeAvailable {
                HistoryManager.sharedManager.editTag(.Add, tag: tag, forId: self.id!) {
                    tags in
                    if tags != nil {
                        if self.tags != tags! {
                            self.tags = tags!
                            let uInfo = ["tags": tags!]
                            NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.tagsChangedNotification, object: self, userInfo: uInfo)
                        }
                    }
                }
            } else {
                AppSingleton.log.error("Tried to add a tag, but DiMe was down")
            }
        } else {
            AppSingleton.log.warning("Adding a tag which is already in the info element")
        }
    }
    
    /// Removes a tag from the information element. Posts a tag changed notification on success.
    /// - Attention: automatically tells DiMe to also perform this operation and uses its response to set own tags
    func removeTag(tag: Tag) {
        if tags.contains(tag) {
            if HistoryManager.sharedManager.dimeAvailable {
                HistoryManager.sharedManager.editTag(.Remove, tag: tag, forId: self.id!) {
                    tags in
                    if tags != nil {
                        if self.tags != tags! {
                            self.tags = tags!
                            let uInfo = ["tags": tags!]
                            NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.tagsChangedNotification, object: self, userInfo: uInfo)
                        }
                    }
                }
            } else {
                AppSingleton.log.error("Tried to remove a tag, but DiMe was down")
            }
        } else {
            AppSingleton.log.error("Tag to remove not found in the info element")
        }
    }
    
    /// Updates own tags from DiMe. Posts a tag notification changed on success.
    func updateTags() {
        DiMeFetcher.retrieveTags(forAppId: appId) {
            tags in
            if tags != nil {
                if self.tags != tags! {
                    self.tags = tags!
                    let uInfo = ["tags": tags!]
                    NSNotificationCenter.defaultCenter().postNotificationName(PeyeConstants.tagsChangedNotification, object: self, userInfo: uInfo)
                }
            }
        }
    }
    
    /// Convenience function to add a tag using a String (creates a new Tag).
    func addTag(tagText: String) {
        addTag(Tag(withText: tagText))
    }
    
    /// Convenience function to remove a tag using a String (for simple tags).
    func removeTag(tagText: String) {
        removeTag(Tag(withText: tagText))
    }
}

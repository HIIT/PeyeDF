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
    fileprivate(set) var tags = [Tag]()
    
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
    override func getDict() -> [String : Any] {
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
            tags = _tags.flatMap({Tag.makeTag(fromJson: $0)})
        }
    }
    
    /// Returns app id using own dictionary
    func getAppId() -> String {
        return theDictionary["appId"]! as! String
    }
    
    /// Adds a reading tag to the information element. If a simple tag was already present, it will be
    /// "upgraded" to a reading tag. If a reading tag with the same name was present adds the new blocks
    /// of text to it.
    /// - Attention: automatically tells DiMe to also perform this operation and uses its response to set own tags
    func addTag(_ newTag: Tag) {
        
        var tagToAdd: Tag
        
        // check if old tags with the same name exists and combine them if so
        // (tags with same name overwrite previous ones in DiMe)
        if let oldTag = tags.getTag(newTag.text) {
            if type(of: oldTag) == Tag.self {
                tagToAdd = newTag
            } else {
                // combine reading tags
                tagToAdd = (oldTag as! ReadingTag).combine(newTag as! ReadingTag)
            }
        } else {
            tagToAdd = newTag
        }
        
        // send data to dime
        if DiMeSession.dimeAvailable {
            DiMePusher.editTag(.Add, tag: tagToAdd, forId: self.id!) {
                tags in
                if tags != nil {
                    if self.tags != tags! {
                        self.tags = tags!
                        let uInfo = ["tags": tags!]
                        NotificationCenter.default.post(name: Notification.Name(rawValue: TagConstants.tagsChangedNotification), object: self, userInfo: uInfo)
                    }
                }
            }
        } else {
            AppSingleton.log.error("Tried to add a tag, but DiMe was down")
        }
    }
    
    /// Subtracts a reading tag from this documents' tags. If the resulting reading tag contains no rects,
    /// it will be "downgraded" to a simple tag.
    /// - Attention: automatically tells DiMe to also perform this operation and uses its response to set own tags
    func subtractTag(_ newTag: ReadingTag) {
        
        guard let oldTag = tags.getTag(newTag.text) else {
            AppSingleton.log.error("Could not find a tag to subtract")
            return
        }
        
        guard let oldReadingTag = oldTag as? ReadingTag else {
            AppSingleton.log.error("Tag to subtract was not a reading tag")
            return
        }
        
        let tagToAdd = oldReadingTag.subtract(newTag)
        
        // send data to dime
        if DiMeSession.dimeAvailable {
            DiMePusher.editTag(.Add, tag: tagToAdd, forId: self.id!) {
                tags in
                if tags != nil {
                    if self.tags != tags! {
                        self.tags = tags!
                        let uInfo = ["tags": tags!]
                        NotificationCenter.default.post(name: Notification.Name(rawValue: TagConstants.tagsChangedNotification), object: self, userInfo: uInfo)
                    }
                }
            }
        } else {
            AppSingleton.log.error("Tried to remove a tag, but DiMe was down")
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
                    NotificationCenter.default.post(name: Notification.Name(rawValue: TagConstants.tagsChangedNotification), object: self, userInfo: uInfo)
                }
            }
        }
    }
    
    /// Convenience function to add a tag using a String (creates a new Tag if it doesn't exists already).
    func addTag(_ tagText: String) {
        // if tag is already present, don't add anything (tags overwrite each other)
        if !tags.containsTag(withText: tagText) {
            addTag(Tag(withText: tagText))
        }
    }
    
    /// Removes a tag using a String.
    /// Deletes the tag completely even if it's a reading tag with some associated text.
    func removeTag(_ tagText: String) {
        let tag = Tag(withText: tagText)
        if tags.containsTag(withText: tagText) {
            if DiMeSession.dimeAvailable {
                DiMePusher.editTag(.Remove, tag: tag, forId: self.id!) {
                    tags in
                    if tags != nil {
                        if self.tags != tags! {
                            self.tags = tags!
                            let uInfo = ["tags": tags!]
                            NotificationCenter.default.post(name: Notification.Name(rawValue: TagConstants.tagsChangedNotification), object: self, userInfo: uInfo)
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
}

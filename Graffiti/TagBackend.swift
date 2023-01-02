//
//  TagBackend.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/1/23.
//

import Foundation

protocol TagBackend: Codable {
    func addTag(_ tag: Tag, to file: TaggedFile)
    func removeTag(withID id: Tag.ID, from file: TaggedFile)
    func loadTags(for path: String) -> [Tag]
    func clearTags(of file: TaggedFile)
}

let kXattrDomain = "com.tom.graffiti-tags"

class XattrTagBackend:  TagBackend, Codable {
    let delimiter: String
    
    
    init() {
        self.delimiter = kDEFAULT_XATTR_DELIM
    }
    
    init(deliminator: String) {
        self.delimiter = deliminator
    }
    
    func addTag(_ tag: Tag, to file: TaggedFile) {
        XattrBridge.appendXAttrAttribute(forFile: "\(file.parent)\(file.filename)", valueOf: tag.value , withKey: kXattrDomain, delimitedBy: delimiter, andError: nil)
    }
    
    func removeTag(withID id: Tag.ID, from file: TaggedFile) {
        let s = xattrString(file: file);
        print("Attr string \(s)")
        XattrBridge.setXAttrAttributeForFile("\(file.parent)\(file.filename)", valueOf: s, withKey: kXattrDomain, andError: nil)
    }
    
    func loadTags(for path: String) -> [Tag] {
        XattrBridge.getXAttrAttributes(forFile: path, withKey: kXattrDomain, delimitedBy: delimiter, andError: nil).map { $0 as? String }.filter { $0 != nil && $0?.isEmpty != true }.map { Tag(value: $0!) }
    }
    
    func xattrString(file: TaggedFile) -> String {
        file.tags.map { $0.value }.joined(separator: delimiter)
    }
    
    func clearTags(of file: TaggedFile) {
        XattrBridge.removeXAttrAttributes(forFile: file.id, withKey: kXattrDomain, andError: nil)
    }
    
}

//class PlistFileTagBackend: NSObject, TagBackend {
//    let path: URL
//    
//    init(path: URL) {
//        self.path = path
//    }
//    
//    private func write(tags: TaggedFile) {
//        let encoder = PropertyListEncoder()
//        
//        if let data = try? encoder.encode(tags) {
//            if FileManager.default.fileExists(atPath: path.path()) {
//                // Update an existing plist
//                try? data.write(to: path)
//            } else {
//                // Create a new plist
//                FileManager.default.createFile(atPath: path.path(), contents: data, attributes: nil)
//            }
//        }
//        
//    }
//    
//    func addTag(_ tag: Tag, to file: TaggedFile) {
//        <#code#>
//    }
//    
//    func removeTag(withID id: Tag.ID, from file: TaggedFile) {
//        <#code#>
//    }
//    
//    func loadTags(for path: String) -> [Tag] {
//        <#code#>
//    }
//    
//    
//}

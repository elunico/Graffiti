//
//  XAttrBackend.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/4/23.
//

import Foundation


class XattrTagBackend: TagBackend {
    static let kXattrDomain = "com.tom.graffiti-tags"
    let delimiter: String
    
    init() {
        self.delimiter = kDEFAULT_XATTR_DELIM
    }
    
    init(deliminator: String) {
        self.delimiter = deliminator
    }
    
    func addTag(_ tag: Tag, to file: TaggedFile) {
        XattrBridge.appendXAttrAttribute(forFile: "\(file.parent)\(file.filename)", valueOf: tag.value , withKey: XattrTagBackend.kXattrDomain, delimitedBy: delimiter, andError: nil)
    }
    
    func removeTag(withID id: Tag.ID, from file: TaggedFile) {
        let s = xattrString(file: file);
        print("Attr string \(s)")
        XattrBridge.setXAttrAttributeForFile("\(file.parent)\(file.filename)", valueOf: s, withKey: XattrTagBackend.kXattrDomain, andError: nil)
    }
    
    func loadTags(for path: String) -> [Tag] {
        XattrBridge.getXAttrAttributes(forFile: path, withKey: XattrTagBackend.kXattrDomain, delimitedBy: delimiter, andError: nil).map { $0 as? String }.filter { $0 != nil && $0?.isEmpty != true }.map { Tag(value: $0!) }
    }
    
    func xattrString(file: TaggedFile) -> String {
        file.tags.map { $0.value }.joined(separator: delimiter)
    }
    
    func clearTags(of file: TaggedFile) {
        XattrBridge.removeXAttrAttributes(forFile: file.id, withKey: XattrTagBackend.kXattrDomain, andError: nil)
    }
    
}

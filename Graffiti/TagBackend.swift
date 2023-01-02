//
//  TagBackend.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/1/23.
//

import Foundation

protocol TagBackend {
    func addTag(_ tag: Tag, to file: TaggedFile)
    func removeTag(withID id: Tag.ID, from file: TaggedFile)
    func loadTags(for path: String) -> [Tag]
    func clearTags(of file: TaggedFile)
    
    // used to implement lazy backend systems or other time delay ones
    // exists here because implementers need to see it
    // default does nothing
    func commitTransactions()
}

extension TagBackend {
    // do nothing by default 
    func commitTransactions() {
        
    }
}

class LazyBackend: TagBackend {
    enum Transaction {
        case Add(tag: Tag, file: TaggedFile)
        case RemoveTag(id: Tag.ID, file: TaggedFile)
        case clearTags(file: TaggedFile)
    }
    
    let backing: TagBackend
    var transactions: [Transaction] = []
    
    init(wrapping backing: TagBackend) {
        self.backing = backing
    }
    
    func addTag(_ tag: Tag, to file: TaggedFile) {
        transactions.append(.Add(tag: tag, file: file))
    }
    
    func removeTag(withID id: Tag.ID, from file: TaggedFile) {
        transactions.append(.RemoveTag(id: id, file: file))
    }
    
    func loadTags(for path: String) -> [Tag] {
        backing.loadTags(for: path)
    }
    
    func clearTags(of file: TaggedFile) {
        transactions.append(.clearTags(file: file))
    }
    
    func commitTransactions() {
        for transaction in transactions {
            switch transaction{
            case .Add(let tag, let file):
                backing.addTag(tag, to: file)
            case .RemoveTag(let tag, let file):
                backing.removeTag(withID: tag, from: file)
            case .clearTags(let file):
                backing.clearTags(of: file)
            }
        }
    }
}

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

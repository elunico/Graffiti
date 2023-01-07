//
//  TaggedFile.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/1/23.
//

import Foundation

class TaggedFile: ObservableObject {
    let parent: String
    let filename: String
    let isDirectory: Bool
    private let backend: TagBackend
    private(set) var tags: Set<Tag> = Set()
    
    init(parent: String, filename: String, backend: TagBackend = XattrTagBackend()) {
        self.parent = parent
        self.filename = filename
        var b: ObjCBool = false
        if FileManager.default.fileExists(atPath: "\(parent)\(filename)", isDirectory: &b) {
            self.isDirectory = b.boolValue
        } else {
            self.isDirectory = false 
        }
        self.backend = backend
        let attrs = backend.loadTags(for: "\(parent)\(filename)")
        print(attrs)
        self.tags = attrs 
    }
    
    func addTag(_ tag: Tag) {
        tags.insert(tag)
        backend.addTag(tag, to: self)
    }

    func removeTag(withID id: Tag.ID) {
        guard let idx = tags.firstIndex(where: { $0.id == id }) else { return }
        tags.remove(at: idx)
        backend.removeTag(withID: id, from: self)
    }
    
    func clearTags() {
        backend.clearTags(of: self)
        tags.removeAll()
    }
    
    func commit() {
        backend.commitTransactions()
    }
}

extension TaggedFile: Identifiable {
    var id: String {
        "\(parent)\(filename)"
    }
}

extension TaggedFile: Equatable, Hashable {
    static func == (lhs: TaggedFile, rhs: TaggedFile) -> Bool {
        lhs.parent == rhs.parent && lhs.filename == rhs.filename
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension TaggedFile {
    // KeyPaths for Table view
    var tagString: String {
        tags.map { $0.value }.joined(separator: ", ")
    }
    
    var tagCount: String {
        tags.count.description
    }
 
    var fileKind: String {
        isDirectory ? "directory" : "file"
    }
}

//
//  TaggedFile.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/1/23.
//

import Foundation

class TaggedFile: ObservableObject, NSCopying {
    func copy(with zone: NSZone? = nil) -> Any {
        let t = TaggedFile(parent: parent, filename: filename, backend: backend)
        t.tags = tags
        return t
    }
    
    let parent: String
    let filename: String
    let isDirectory: Bool
    private weak var backend: TagBackend?
    @Published var tags: Set<Tag> = Set()
    
    var searchableMetadataString: String {
        tags.map { $0.searchableMetadataString }.joined(separator: " ")
    }
    
    convenience init(atPath path: String, backend: TagBackend?) {
        var components = path.components(separatedBy: "/")
        let filename = components.removeLast()
        let parent = components.joined(separator: "/")
        self.init(parent: parent, filename: filename, backend: backend)
    }
    
    init(parent: String, filename: String, backend: TagBackend? = FileTagBackend()) {
        self.parent = parent
        self.filename = filename
        var b: ObjCBool = false
        if FileManager.default.fileExists(atPath: "\(parent)\(filename)", isDirectory: &b) {
            self.isDirectory = b.boolValue
        } else {
            self.isDirectory = false 
        }
        self.backend = backend
        let attrs = backend?.loadTags(at: "\(parent)\(filename)")
        self.tags = attrs ?? []
    }
    
    func addTag(_ tag: Tag) throws {
        // TODO: does this add tags twice?
        tags.insert(tag)
        try backend?.addTag(tag, to: self)
    }

    func removeTag(withID id: Tag.ID) {
        guard let idx = tags.firstIndex(where: { $0.id == id }) else { return }
        tags.remove(at: idx)
        backend?.removeTag(withID: id, from: self)
    }
    
    func clearTags() {
        backend?.clearTags(of: self)
        tags.removeAll()
    }
}

extension TaggedFile: Identifiable {
    var id: String {
        "\(parent)\(filename)"
    }
}

extension TaggedFile {
    var absoluteURL: URL {
        URL(fileURLWithPath: (parent as NSString).appendingPathComponent(filename))
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
        tags.map { $0.description }.joined(separator: ", ")
    }
    
    var tagCount: String {
        tags.count.description
    }
 
    var fileKind: String {
        isDirectory ? "directory" : "file"
    }
}

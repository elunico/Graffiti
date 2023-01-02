//
//  TaggedFile.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/1/23.
//

import Foundation


struct Tag : Equatable, Hashable, Identifiable, Codable {
    
    var id: UUID = UUID()
    var value: String
}

class TaggedFile: Identifiable, Equatable, ObservableObject {
    static func == (lhs: TaggedFile, rhs: TaggedFile) -> Bool {
        return lhs.parent == rhs.parent && lhs.filename == rhs.filename
    }
    
    var id: String {
        "\(parent)\(filename)"
    }
    
    var parent: String
    var filename: String
    
    var backend: TagBackend
    
    private(set) var tags: [Tag] = []
    
    
    var tagString: String {
        tags.map { $0.value }.joined(separator: ", ")
    }
    
    var tagCount: String {
        tags.count.description
    }
    
    init(parent: String, filename: String, backend: TagBackend = XattrTagBackend()) {
        self.parent = parent
        self.filename = filename
        self.backend = backend
        let attrs = backend.loadTags(for: "\(parent)\(filename)")
        print(attrs)
        self.tags = attrs 
    }
    
    func addTag(_ tag: Tag) {
        tags.append(tag)
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
}

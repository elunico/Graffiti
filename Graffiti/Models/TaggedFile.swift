//
//  TaggedFile.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/1/23.
//

import Foundation

class TaggedFile: Identifiable, Equatable, ObservableObject {
    static func == (lhs: TaggedFile, rhs: TaggedFile) -> Bool {
        lhs.parent == rhs.parent && lhs.filename == rhs.filename
    }
       
    let parent: String
    let filename: String
    private let backend: TagBackend
    private(set) var tags: [Tag] = []
    
    var tagString: String {
        tags.map { $0.value }.joined(separator: ", ")
    }
    
    var tagCount: String {
        tags.count.description
    }
    
    var id: String {
        "\(parent)\(filename)"
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
    
    func commit() {
        backend.commitTransactions()
    }
}

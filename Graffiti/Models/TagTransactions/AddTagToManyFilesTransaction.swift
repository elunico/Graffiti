//
//  TagTransaction.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/20/23.
//

import Foundation

class AddTagToManyFilesTransaction: TagTransaction {
    var backend: TagBackend
    var tag: Tag
    var files: [TaggedFile]
    
    init(backend: TagBackend, tag: Tag, files: [TaggedFile]) {
        self.backend = backend
        self.tag = tag
        self.files = files
    }
    
    func perform() {
        files.forEach { backend.addTag(tag, to: $0); tag.acquire() }
    }
    
    func undo() {
        files.forEach { backend.removeTag(withID: tag.id, from: $0); tag.relieve() }
    }
}

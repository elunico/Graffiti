//
//  TagTransaction.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/20/23.
//


import Foundation

class AddTagTransaction: TagTransaction {
    var backend: TagBackend
    var tag: Tag
    var file: TaggedFile
    
    init(backend: TagBackend, tag: Tag, file: TaggedFile) {
        self.backend = backend
        self.tag = tag
        self.file = file
    }
    
    func perform() {
        tag.acquire()
        print("Performing add")
        backend.addTag(tag, to: file)
    }
    
    func undo() {
        tag.relieve()
        backend.removeTag(withID: tag.id, from: file)
    }
}

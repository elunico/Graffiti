//
//  TagTransaction.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/20/23.
//


import Foundation


class RemoveTagTransaction: TagTransaction {
    var backend: TagBackend
    var tag: Tag
    var file: TaggedFile
    
    init(backend: TagBackend, tag: Tag, file: TaggedFile) {
        self.backend = backend
        self.tag = tag
        self.file = file
    }
    
    func perform() {
        backend.removeTag(withID: tag.id, from: file)
        tag.relieve()
    }
    
    func undo() {
        tag.acquire()
        backend.addTag(tag, to: file)
    }
}


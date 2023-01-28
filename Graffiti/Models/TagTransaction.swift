//
//  TagTransaction.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/28/23.
//

import Foundation

protocol TagTransaction {
    func perform()
    
    func undo()
    
    func redo()
}

extension TagTransaction {
    func redo() { perform() }
}

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
        backend.addTag(tag, to: file)
    }
    
    func undo() {
        backend.removeTag(withID: tag.id, from: file)
    }
}

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
        files.forEach { backend.addTag(tag, to: $0) }
    }
    
    func undo() {
        files.forEach { backend.removeTag(withID: tag.id, from: $0) }
    }
}

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
    }
    
    func undo() {
        backend.addTag(tag, to: file)
    }
}

class RemoveTagFromManyFilesTransaction: TagTransaction {
    var backend: TagBackend
    var tag: Tag
    var files: [TaggedFile]
    
    init(backend: TagBackend, tag: Tag, files: [TaggedFile]) {
        self.backend = backend
        self.tag = tag
        self.files = files
    }
    
    func perform() {
        files.forEach { backend.removeTag(withID: tag.id, from: $0) }
    }
    
    func undo() {
        files.forEach { backend.addTag(tag, to: $0) }
    }
}

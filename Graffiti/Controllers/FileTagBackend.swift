//
//  FileTagBackend.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/7/23.
//

import Foundation

class FileTagBackend: TagBackend {
    
    func loadTags(at path: String) -> Set<Tag> {
        return tags[path] ?? []
    }
    
    var tags: [TaggedFile.ID: Set<Tag>] = [:]
    var writer: FileWriter
    var directory: URL
    var dirty: Bool = false
    
    init(forFilesIn directory: URL, writer: FileWriter) {
        self.directory = directory
        self.writer = writer
        // todo: fix this
        var intermediate = try! writer.loadFrom(path: "\(directory.absolutePath)\(FileTagBackend.filePrefix)\(writer.fileExtension)")
        for (path, tags) in intermediate {
            print("path: \(path)")
            self.tags[path] = tags
        }
    }
    
    func addTag(_ tag: Tag, to file: TaggedFile) {
        dirty = true
        if tags[file.id] == nil {
            tags[file.id] = [tag]
        } else {
            tags[file.id]!.insert(tag)
        }
    }
    
    func removeTag(withID id: Tag.ID, from file: TaggedFile) {
        guard let a = tags[file.id]?.first(where: {$0.id == id}) else { return }
        dirty = true
        tags[file.id]?.remove(a)
    }

    func clearTags(of file: TaggedFile) {
        dirty = true
        tags[file.id]?.removeAll()
    }
    
    var implementationProhibitedCharacters: Set<Character> {
        writer.fileProhibitedCharacters
    }
    
    func commitTransactions() {
        if dirty {
            writer.saveTo(path: saveFile, tags: tags)
            dirty = false 
        }
    }
    
    static let filePrefix = "com-tom-graffiti.tagfile";
    var saveFile: String {
        let path = "\(directory.absolutePath)\(FileTagBackend.filePrefix)\(writer.fileExtension)"
        print(path)
        return path
    }
    
}

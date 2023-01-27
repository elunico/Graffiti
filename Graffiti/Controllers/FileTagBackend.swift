//
//  FileTagBackend.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/7/23.
//

import Foundation

class FileTagBackend: TagBackend {
    
    func copy(with zone: NSZone? = nil) -> Any {
        guard var f = try? FileTagBackend( withFileName: filename, forFilesIn: directory, writer: writer) else { fatalError("Failed to produce copy() of FileTagBackend") }
//        f.tags = tags
        f.dirty = dirty
        return f
    }
    private var lastAccessTime: Date? = nil
    private var cachedData: [String: Set<Tag>] = [:]
    
    func reloadData() throws {
        try getSandboxedAccess(to: directory.absolutePath, thenPerform: { path in
            let intermediate = try writer.loadFrom(path: saveFile)
            let data = intermediate.tagData
            for (p, tags) in data {
                cachedData[p] = tags
            }
        })
        
    }
    
    func loadTags(at path: String) -> Set<Tag> {
        let date = (try? FileManager.default.attributesOfItem(atPath: saveFile)[FileAttributeKey.modificationDate]) as? Date
        if date == nil || lastAccessTime == nil || (lastAccessTime! != date! && (lastAccessTime! as NSDate).laterDate(date!) == date!) {
            try? reloadData()
            self.lastAccessTime = date
        }
        return cachedData[path] ?? []
    }
    
//    var tags: [TaggedFile.ID: Set<Tag>] = [:]
    var writer: FileWriter
    var directory: URL
    var dirty: Bool = false
    var filename: String?
    
    init(withFileName filename: String?, forFilesIn directory: URL, writer: FileWriter) throws {
        self.directory = directory
        self.writer = writer
        self.filename = filename
        print("in init")
        try self.reloadData()
        print("after init")
//        let intermediate = try writer.loadFrom(path: type(of: writer).writePath(in: directory, named: filename))
//        let data = intermediate.tagData
//        for (path, tags) in data {
//            self.tags[path] = tags
//        }
    }
    
    func addTag(_ tag: Tag, to file: TaggedFile) {
        dirty = true
//        owner?.getFile(withID: file.)
        file.tags.insert(tag)
//        if tags[file.id] == nil {
//            tags[file.id] = [tag]
//        } else {
//            tags[file.id]!.insert(tag)
//        }
    }
    
    func removeTag(withID id: Tag.ID, from file: TaggedFile) {
        guard let t = file.tags.first(where: { $0.id == id }) else { return }
        dirty = true
        file.tags.remove(t)
    }

    func clearTags(of file: TaggedFile) {
        dirty = true
        file.tags.removeAll()
    }
    
    var implementationProhibitedCharacters: Set<Character> {
        writer.fileProhibitedCharacters
    }
    
    func commit(files: [TaggedFile]) {
        if dirty {
            let path = saveFile
            let tags = Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0.tags) })
            writer.saveTo(path: path, store: TagStore(tagData: tags))
            dirty = false 
        }
    }
    
    static let filePrefix = "com-tom-graffiti.tagfile";
    var saveFile: String {
        type(of: writer).writePath(in: directory, named: filename)
    }
    
}

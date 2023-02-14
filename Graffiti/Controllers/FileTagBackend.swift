//
//  FileTagBackend.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/7/23.
//

import Foundation

class FileTagBackend: TagBackend {
    
    func copy(with zone: NSZone? = nil) -> Any {
        do {
            let f = try FileTagBackend( withFileName: filename, forFilesIn: directory, writer: writer)
            f.dirty = dirty
            return f
        } catch let error {
            print(error)
            fatalError()
        }
    }
    
    private var lastAccessTime: Date? = nil
    private var cachedData: [String: Set<Tag>] = [:]
    
    func reloadData()  throws {
        
        try getSandboxedAccess(to: directory.absolutePath, thenPerform: { path in
            do {
                let intermediate = try writer.loadFrom(path: saveFile)
                let data = intermediate.tagData
                for (p, tags) in data {
                    cachedData[p] = tags
                }
            } catch let error {
                print("reloadData() error \(error)")
                
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
    
    var writer: FileWriter
    var directory: URL
    var dirty: Bool = false
    var format: Tag.ImageFormat
    var filename: String?
    
    init(withFileName filename: String?, forFilesIn directory: URL, writer: FileWriter, format: Tag.ImageFormat = .url) throws {
        self.directory = directory
        self.writer = writer
        self.filename = filename
        self.format = format
        try self.reloadData()
        
    }
    
    init() {
        self.writer = CompressedCustomTagStoreWriter()
        self.directory = URL(fileURLWithPath: "/")
        self.filename = ""
        self.format = .url
    }
    
    func removeTagText(from file: TaggedFile) {
        dirty = true 
        file.tags.forEach { $0.imageTextContent.content.removeAll(); $0.recoginitionState = .uninitialized }
    }
    
    func addTag(_ tag: Tag, to file: TaggedFile) {
        dirty = true
        file.tags.insert(tag)
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

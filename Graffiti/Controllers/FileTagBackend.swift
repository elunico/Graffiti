//
//  FileTagBackend.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/7/23.
//

import Foundation

class FileTagBackend: TagBackend {

    private static func appending(s1: String?, s2: String?) -> String? {
        if let left = s1, let right = s2 {
            return left + right
        }
        return nil
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        do {
            let f = try FileTagBackend(withFileName: filename, forFilesIn: directory, writer: writer)
            return f
        } catch let error {
//            print(error)
            fatalError()
        }
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
    
    var writer: FileWriter
    var directory: URL
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
        file.tags.forEach { $0.imageTextContent.removeAll(); $0.recoginitionState = .uninitialized }
    }
    
    func addTag(_ tag: Tag, to file: TaggedFile) throws {
        if !isValid(tag: tag) {
            throw TagBackendError.illegalCharacter
        }
        file.tags.insert(tag)
    }
    
    func removeTag(withID id: Tag.ID, from file: TaggedFile) {
        guard let t = file.tags.first(where: { $0.id == id }) else { return }
        file.tags.remove(t)
    }
    
    func clearTags(of file: TaggedFile) {
        file.tags.removeAll()
    }
    
    var implementationProhibitedCharacters: Set<Character> {
        writer.fileProhibitedCharacters
    }
    
    func commit(files: [TaggedFile], force: Bool = false) {
        // TODO: probably want to alert the user and propogate this error
        let path = saveFile
        let tags = Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0.tags) })
        try? writer.saveTo(path: path, store: TagStore(tagData: tags))
    }
    
    func performAutosave(files: [TaggedFile], suffix: String) {
        if let filename {
            let path = autosaveFile
            let tags = Dictionary(uniqueKeysWithValues: files.map{ ($0.id, $0.tags) })
            try? writer.saveTo(path: path, store: TagStore(tagData: tags))
        }
    }
    
    func removeAutosave(suffix: String) {
        try? FileManager.default.removeItem(atPath: autosaveFile)
    }
    
    /// this method should overwrite existing data with the data found in the autosave file
    /// can be a NOP if backend does not support autosave
    func restoreFromAutosave(suffixedWith: String)  {
        let autosaveURL = URL(fileURLWithPath: autosaveFile)
        let saveURL = URL(fileURLWithPath: saveFile)
        try! FileManager.default.removeItem(at: saveURL)
        try! FileManager.default.moveItem(at: autosaveURL, to: saveURL)
    }
    
    func hasAutosave(suffixedWith suffix: String) -> Bool {
        let name = FileTagBackend.appending(s1: filename, s2: suffix)
        let path = type(of: writer).writePath(in: directory, named: name)
        return FileManager.default.fileExists(atPath: path)
    }
    
    static let filePrefix = "com-tom-graffiti.tagfile";
    var saveFile: String {
        type(of: writer).writePath(in: directory, named: filename)
    }
    
    var autosaveFile: String {
        type(of: writer).writePath(in: directory, named: FileTagBackend.appending(s1: filename ?? "UKNTMP", s2: ".tmpstore"))
    }
    
}

//
//  TaggedDirectory.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/2/23.
//

import Foundation


class TaggedDirectory: ObservableObject, NSCopying {
    func copy(with zone: NSZone? = nil) -> Any {
        let d = TaggedDirectory()
        d.directory = directory
        d.files = files.map { $0.copy() as! TaggedFile }
        d.backend = backend.copy() as! TagBackend
        d.indexMap = indexMap
        d.filterPredicate = filterPredicate
//        d.setFilter(from: self.query)
        return d 
    }
    
    static let empty: TaggedDirectory = TaggedDirectory()
    private static let alwaysTrue: (TaggedFile) -> Bool = { _ in true }
    
    @Published var directory: String
    @Published var files: [TaggedFile] = []
    private var backend: TagBackend
    private var indexMap: [TaggedFile.ID: Int] = [:]
    
    private var filterPredicate: (TaggedFile) -> Bool = alwaysTrue
    var cachedFiles: [TaggedFile]? = nil
    private var query: String = ""
    
    private init() {
        self.directory = ""
        self.backend = XattrTagBackend()
    }
    
    func load(directory: String, format: Format) throws {
        self.files.removeAll()
        self.indexMap.removeAll()
        self.directory = directory
        guard let backend = try format.implementation(in: URL(fileURLWithPath: directory)) else { print("Invalid"); return }
        self.backend = backend 
        print("after implementation")
        let content = try getContentsOfDirectory(atPath: directory)
        var idx = 0
        for file in content {
            let tf = TaggedFile(parent: directory, filename: file, backend: backend)
            files.append(tf)
            indexMap[tf.id] = idx
            idx += 1
        }
    }
    
    func getFile(withID id: String) -> TaggedFile? {
        guard let index = indexMap[id] else { return nil }
        return files[index]
    }
    
    func getFiles(withIDs ids: Set<String>) -> Set<TaggedFile> {
        Set(ids.map { indexMap[$0] }.filter { $0 != nil }.map { files[$0!] })
    }
    
    var tagStore: String? {
        (backend as? FileTagBackend)?.saveFile
    }
    
    func commit() {
        backend.commit(files: files)
     
    }
    
    func addTag(_ tag: Tag, to file: TaggedFile) {
        backend.addTag(tag, to: file)
    }
    func removeTag(withID id: Tag.ID, from file: TaggedFile) {
        backend.removeTag(withID: id, from: file)
    }
    func loadTags(at path: String) -> Set<Tag> {
        let t = backend.loadTags(at: path)
        return t
    }
    func clearTags(of file: TaggedFile) {
        backend.clearTags(of: file)
    }
    
    func commit(files: [TaggedFile]) {
        backend.commit(files: files)
    }
    
    /// special characters used by the Tag backend that are
    /// prohibited from being used in Tags themselves
    var implementationProhibitedCharacters: Set<Character> { backend.implementationProhibitedCharacters }


    var prohibitedCharacters: Set<Character> {
        backend.prohibitedCharacters
    }

}

// Functions for filtering
extension TaggedDirectory {
    var filteredFiles: [TaggedFile] {
        if cachedFiles == nil {
            cachedFiles = files
        }
        return cachedFiles!
    }
    
//    func setFilter(from query: String) {
//        self.query = query
//        if query.isEmpty {
//            filterPredicate = TaggedDirectory.alwaysTrue
//            cachedFiles = files
//            return
//        }
//        let results = query.split(separator: "|").map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }.map{ $0.split(separator: "&").map{ s in s.trimmingCharacters(in: .whitespacesAndNewlines)} }
//        filterPredicate = {
//            file in results.anySatisfy {
//                conjunction in conjunction.allSatisfy {
//                    text in
//                    let substr = text[text.index(after: text.startIndex)...]
//                    return (text.hasPrefix("!") && !file.tagString.contains(substr) && !file.filename.contains(substr)) || (!text.hasPrefix("!") && ((file.tagString.contains(text) || file.filename.contains(text))))
//                }
//            }
//        }
//        cachedFiles = files.filter(filterPredicate)
//    }
//
    func filter(by query: String) -> [TaggedFile] {
        self.query = query
        if query.isEmpty {
            filterPredicate = TaggedDirectory.alwaysTrue
            cachedFiles = files
            return files
        }
        let results = query.split(separator: "|").map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }.map{ $0.split(separator: "&").map{ s in s.trimmingCharacters(in: .whitespacesAndNewlines)} }
        filterPredicate = {
            file in results.anySatisfy {
                conjunction in conjunction.allSatisfy {
                    text in
                    let substr = text[text.index(after: text.startIndex)...]
                    return (text.hasPrefix("!") && !file.tagString.contains(substr) && !file.filename.contains(substr)) || (!text.hasPrefix("!") && ((file.tagString.contains(text) || file.filename.contains(text))))
                }
            }
        }
        return files.filter(filterPredicate)
    }
    
//    func clearFilter() {
//        setFilter(from: "")
//    }
}

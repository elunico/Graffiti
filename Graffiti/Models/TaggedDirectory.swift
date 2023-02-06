//
//  TaggedDirectory.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/2/23.
//

import Foundation

class Sorter: SortComparator {
    typealias Compared = TaggedFile
    
    static func == (lhs: Sorter, rhs: Sorter) -> Bool {
        lhs.order == rhs.order
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(order)
    }
    
    var order: SortOrder = .forward
    var keypath: KeyPath<TaggedFile, String>
    
    init(keypath: KeyPath<TaggedFile, String>) {
        self.keypath = keypath
    }
    
    func compare(_ lhs: TaggedFile, _ rhs: TaggedFile) -> ComparisonResult {
        if order == .forward {
            return lhs[keyPath: self.keypath].localizedCaseInsensitiveCompare(rhs[keyPath: self.keypath])
        } else {
            return rhs[keyPath: self.keypath].localizedCaseInsensitiveCompare(lhs[keyPath: self.keypath])

        }
    }
}

class TaggedDirectory: ObservableObject, NSCopying {
    func copy(with zone: NSZone? = nil) -> Any {
        let d = TaggedDirectory()
        d.directory = directory
        d.files = files.map { $0.copy() as! TaggedFile }
        d.backend = backend.copy() as! TagBackend
        d.indexMap = indexMap
        d.filterPredicate = filterPredicate
        return d 
    }
    
    static let empty: TaggedDirectory = TaggedDirectory()
    private static let alwaysTrue: (TaggedFile) -> Bool = { _ in true }
    
    @Published var directory: String
    @Published var files: [TaggedFile] = []
    private var backend: TagBackend
    private var indexMap: [TaggedFile.ID: Int] = [:]
    
    private var filterPredicate: (TaggedFile) -> Bool = alwaysTrue
    private var query: String = ""
    
    @Published private(set) var transactions: [TagTransaction] = []
    @Published private(set) var redoStack: [TagTransaction] = []
    
    private init() {
        self.directory = ""
        self.backend = XattrTagBackend()
    }
    
    func sort(with sorter: Sorter?) {
        guard let sorter else { return }
        self.files.sort(using: sorter)
        objectWillChange.send()
    }
    
    func load(directory: String, filename: String? = nil, format: Format) throws {
        self.files.removeAll()
        self.indexMap.removeAll()
        self.directory = directory
        guard let backend = try format.implementation(in: URL(fileURLWithPath: directory), withFileName: filename) else { return }
        self.backend = backend
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
    
    func addTags(_ tag: Tag, toAll files: [TaggedFile]) {
        transactions.append(AddTagToManyFilesTransaction(backend: backend, tag: tag, files: files))
        transactions.last?.perform()
        invalidateRedo()
    }
    
    func addTag(_ tag: Tag, to file: TaggedFile) {
//        backend.addTag(tag, to: file)
        transactions.append(AddTagTransaction(backend: backend, tag: tag, file: file))
        transactions.last?.perform()
        invalidateRedo()
    }
    
    func removeTag(withID id: Tag.ID, from file: TaggedFile) {
//        backend.removeTag(withID: id, from: file)
        transactions.append(RemoveTagTransaction(backend: backend, tag: Tag(value: id), file: file))
        transactions.last?.perform()
        invalidateRedo()
    }
    
    func removeTag(withID id: Tag.ID, fromAll files: [TaggedFile]) {
//        backend.removeTag(withID: id, from: file)
        transactions.append(RemoveTagFromManyFilesTransaction(backend: backend, tag: Tag(value: id), files: files))
        transactions.last?.perform()
        invalidateRedo()
    }
    
    func invalidateRedo() {
        redoStack.removeAll()
    }
    
    func invalidateUndo() {
        transactions.removeAll()
    }
    
    func undo() {
        guard let t = transactions.popLast() else { print("Nothing to undo"); return }
        t.undo()
        redoStack.append(t)
    }
    
    func redo() {
        guard let t = redoStack.popLast() else { print("Nothing to redo"); return }
        t.redo()
        transactions.append(t)
    }
    
    func loadTags(at path: String) -> Set<Tag> {
        let t = backend.loadTags(at: path)
        invalidateUndo()
        return t
    }
    
    func clearTags(of file: TaggedFile) {
        backend.clearTags(of: file)
        invalidateUndo()
        invalidateRedo()
    }
    
    func commit() {
        backend.commit(files: files)
        invalidateUndo()
    }
    
    func commit(files: [TaggedFile]) {
        backend.commit(files: files)
        invalidateUndo()
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

    func filter(by query: String) -> [TaggedFile] {
        self.query = query
        if query.isEmpty {
            filterPredicate = TaggedDirectory.alwaysTrue
        } else {
            let results = query.split(separator: "|").map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }.map{ $0.split(separator: "&").map{ s in s.trimmingCharacters(in: .whitespacesAndNewlines)} }
            filterPredicate = {
                file in results.anySatisfy {
                    conjunction in conjunction.allSatisfy {
                        text in
                        let substr = text[text.index(after: text.startIndex)...]
                        return (text.hasPrefix("!") && !file.tagString.localizedCaseInsensitiveContains(substr) && !file.filename.localizedCaseInsensitiveContains(substr)) || (!text.hasPrefix("!") && ((file.tagString.localizedCaseInsensitiveContains(text) || file.filename.localizedCaseInsensitiveContains(text))))
                    }
                }
            }
        }
        return files.filter(filterPredicate)
    }
}

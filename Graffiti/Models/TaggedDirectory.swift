//
//  TaggedDirectory.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/2/23.
//

import Foundation
import Vision
import AppKit
import CoreML
import CoreImage

enum LoadResult: Error {
    case ExistingAutosave
}

class TaggedDirectory: ObservableObject {
    enum TaggedState {
        case all, tagged, untagged
    }
    
    static let empty: TaggedDirectory = TaggedDirectory()
    private static let alwaysTrue: (TaggedFile) -> Bool = { _ in true }
    
    @Published var directory: String
    @Published var files: [TaggedFile] = []
    private var backend: TagBackend?
    private var indexMap: [TaggedFile.ID: Int] = [:]
    
    private var filterPredicate: (TaggedFile) -> Bool = alwaysTrue
    private var query: String = ""
    
    @Published private(set) var transactions: [TagTransaction] = []
    @Published private(set) var redoStack: [TagTransaction] = []
    
//    @Published var doUpdate: Bool = false
    
    private var queue = DispatchQueue(label: "imageProcessor", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .workItem, target: DispatchQueue.global(qos: .userInitiated))

    
    func imageVisionSet(doVision: Bool) {
        if doVision {
            performVisionActions()
        } else {
            files.forEach { file in
                backend?.removeTagText(from: file)
                file.tags.forEach { tag in tag.recoginitionState = .uninitialized }
            }
        }
    }
    
    func didMutate() {
        print("Performing autosave commmit")
        print("How many files? \(files.count)")
        objectWillChange.send()
        self.performAutosave()
    }
    
    func reset() {
        directory = ""
        files = []
        indexMap = [:]
        backend = nil
        
        filterPredicate = TaggedDirectory.alwaysTrue
        query = ""
        
        transactions = []
        redoStack = []
    }
    
    private init() {
        self.directory = ""
        self.backend = nil
    }
    
    func sort(with sorter: Sorter?) {
        guard let sorter else { return }
        self.files.sort(using: sorter)
        objectWillChange.send()
    }
    

    func loadAutosave(directory: String, filename: String? = nil, format: Format, doTextRecognition: Bool = true)  throws {
        try setBackend(directory: directory, filename: filename, format: format)
        backend!.restoreFromAutosave(suffixedWith: ".tmpstore")
        try load(directory: directory, filename: filename, format: format, doTextRecognition: doTextRecognition)
    }
    
    func setBackend(directory: String, filename: String? = nil, format: Format) throws {
        if backend != nil { return }
        let backend = try format.implementation(in: URL(fileURLWithPath: directory), withFileName: filename)
        self.backend = backend
    }
    
    func hasTemporaryAutosave() -> Bool {
        let result = backend?.hasAutosave(suffixedWith: ".tmpstore")
        return result != nil && result!
    }
    
    func removeAutosave() {
        backend?.removeAutosave(suffix: ".tmpstore")
    }
    
    func load(directory: String, filename: String? = nil, format: Format, doTextRecognition: Bool = true)  throws {
//        print("In directory filename is \(filename)")
        self.indexMap.removeAll()
        self.files.removeAll()
        self.directory = directory
        try setBackend(directory: directory, filename: filename, format: format)
        let content = try  getContentsOfDirectory(atPath: directory)
        var idx = 0
        for file in content {
            let tf = TaggedFile(parent: directory, filename: file, backend: backend)
            files.append(tf)
            indexMap[tf.id] = idx
            idx += 1
        }
        if doTextRecognition {
            performVisionActions()
        }
    }
    
    func getFile(withID id: String) -> TaggedFile? {
        guard let index = indexMap[id] else { return nil }
        return files[index]
    }
    
    func getFiles(withIDs ids: Set<String>) -> Set<TaggedFile> {
        return Set(ids.map { indexMap[$0] }.filter { $0 != nil }.map { files[$0!] })
    }
    
    var tagStore: String? {
        (backend as? FileTagBackend)?.saveFile
    }
    
    func addTags(_ tag: Tag, toAll files: [TaggedFile]) throws {
        if let backend {
            if !backend.isValid(tag: tag) {
                throw TagBackendError.illegalCharacter
            }
            transactions.append(AddTagToManyFilesTransaction(backend: backend, tag: tag, files: files))
        // TODO: should this if go to the end of the function
        }
        transactions.last?.perform()
        invalidateRedo()
        didMutate()
    }
    
    func addTag(_ tag: Tag, to file: TaggedFile) throws {
        // TODO: should check backend for prohibited chars and throw or then add and perform transaction
        if let backend {
            if !backend.isValid(tag: tag) {
                throw TagBackendError.illegalCharacter
            }
            transactions.append(AddTagTransaction(backend: backend, tag: tag, file: file))
        }
        transactions.last?.perform()
        invalidateRedo()
        didMutate()
    }
    
    func removeTag(withString string: String, from file: TaggedFile) {
        let tag = Tag.tag(withString: string)
        if let backend {
            transactions.append(RemoveTagTransaction(backend: backend, tag: tag, file: file))
        }
        transactions.last?.perform()
        invalidateRedo()
        didMutate()
    }
    
    func removeTag(withID id: Tag.ID, from file: TaggedFile) {
        guard let tag = Tag.tag(fromID: id) else { return }
        if let backend {
            transactions.append(RemoveTagTransaction(backend: backend, tag: tag, file: file))
        }
        transactions.last?.perform()
        invalidateRedo()
        didMutate()
    }
    
    
    func removeTag(withID id: Tag.ID, fromAll files: [TaggedFile]) {
        guard let tag = Tag.tag(fromID: id) else { return }
        if let backend {
            transactions.append(RemoveTagFromManyFilesTransaction(backend: backend, tag: tag, files: files))
        }
        transactions.last?.perform()
        invalidateRedo()
        didMutate()
    }
    
    func invalidateRedo() {
        redoStack.removeAll()
        Tag.runGarbageCollection()
    }
    
    func invalidateUndo() {
        transactions.removeAll()
        Tag.runGarbageCollection()
    }
    
    func undo() {
        guard let t = transactions.popLast() else { print("Nothing to undo"); return }
        t.undo()
        redoStack.append(t)
        didMutate()
    }
    
    func redo() {
        guard let t = redoStack.popLast() else { print("Nothing to redo"); return }
        t.redo()
        transactions.append(t)
        didMutate()
    }
    
    func loadTags(at path: String) -> Set<Tag> {
        let t = backend?.loadTags(at: path) ?? []
        invalidateUndo()
        didMutate()
        return t
    }
    
    func clearTags(of file: TaggedFile) {
        file.tags.forEach { $0.relieve() }
        backend?.clearTags(of: file)
        invalidateUndo()
        invalidateRedo()
        didMutate()
    }
    
    func performAutosave() {
        backend?.performAutosave(files: self.files, suffix: ".tmpstore")
    }
    
    func persist() {
        backend?.commit(files: files, force: true)
    }
    
    func commit() {
        commit(files: self.files)
    }
    
    func commit(files: [TaggedFile]) {
        persist()
        // TODO: why is this here? removing it seems to fix an issue with converting image format erasing all data from the tagstore
//        self.indexMap.removeAll()
//        self.files.removeAll(keepingCapacity: true)
        invalidateUndo()
        invalidateRedo()
        print("Removing autosave temporary file")
        backend?.removeAutosave(suffix: ".tmpstore")
    }
    
    func clearTagThumbnails() {
        for file in files {
            for tag in file.tags {
                tag.thumbnail = nil
            }
        }
    }
    
    /// special characters used by the Tag backend that are
    /// prohibited from being used in Tags themselves
    var implementationProhibitedCharacters: Set<Character> { backend?.implementationProhibitedCharacters ?? [] }


    var prohibitedCharacters: Set<Character> {
        backend?.prohibitedCharacters ?? []
    }
    
    func convertTagStorage(to format: Tag.ImageFormat) {
        for file in files {
            for tag in file.tags {
                tag.imageFormat = format
            }
        }
        commit()
    }

}

// Functions for filtering
extension TaggedDirectory {

    func filter(by query: String, within state: TaggedState = .all) -> [TaggedFile] {
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
                        return (text.hasPrefix("!") && !file.searchableMetadataString.localizedCaseInsensitiveContains(substr) && !file.filename.localizedCaseInsensitiveContains(substr)) || (!text.hasPrefix("!") && ((file.searchableMetadataString.localizedCaseInsensitiveContains(text) || file.filename.localizedCaseInsensitiveContains(text))))
                    }
                }
            }
        }
        switch state {
        case .all:
            return files.filter(filterPredicate)
        case .untagged:
            return files.filter { $0.tags.count == 0 && filterPredicate($0) }
        case .tagged:
            return files.filter { $0.tags.count > 0 && filterPredicate($0) }
        }
    }
}

extension TaggedDirectory {
    func performVisionActions() {
        // TODO: taggedDirectory acts as a singleton in the application so there is only one instance of it active in normal use
        // but this is called in AddTag and could be called many times before completion
        queue.async { [weak self] in
            for file in self?.files ?? [] {
                for tag in file.tags where tag.recoginitionState == .uninitialized {
                    tag.detectText()
                    tag.detectObjects()
                }
            }
        }
    }
    
}

extension TaggedDirectory: NSCopying {
    func copy(with zone: NSZone? = nil) -> Any {
        let d = TaggedDirectory()
        d.directory = directory
        d.files = files.map { $0.copy() as! TaggedFile }
        d.backend = backend?.copy() as? TagBackend
        d.indexMap = indexMap
        d.filterPredicate = filterPredicate
        return d
    }
}

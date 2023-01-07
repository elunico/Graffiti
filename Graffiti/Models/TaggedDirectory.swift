//
//  TaggedDirectory.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/2/23.
//

import Foundation

class TaggedDirectory: ObservableObject {
    static let empty: TaggedDirectory = TaggedDirectory()
    private static let alwaysTrue: (TaggedFile) -> Bool = { _ in true }
    
    @Published var directory: String
    @Published var files: [TaggedFile] = []
    private var backend: TagBackend
    private var indexMap: [TaggedFile.ID: Int] = [:]
    
    private var filterPredicate: (TaggedFile) -> Bool = alwaysTrue
    private var cachedFiles: [TaggedFile]? = nil

    var allFiles: [TaggedFile] {
        files
    }
    
    private init() {
        self.directory = ""
        self.backend = XattrTagBackend()
    }
    
    func load(directory: String, backend: TagBackend = XattrTagBackend()) {
        self.files.removeAll()
        self.indexMap.removeAll()
        self.directory = directory
        self.backend = backend
        
        let content = try! FileManager().contentsOfDirectory(atPath: directory)
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
}

// Functions for filtering
extension TaggedDirectory {
    var filteredFiles: [TaggedFile] {
        cachedFiles != nil ? cachedFiles! : files
    }
    
    func setFilter(from query: String) {
        if query.isEmpty {
            filterPredicate = TaggedDirectory.alwaysTrue
            return
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
        cachedFiles = files.filter(filterPredicate)
    }
    
    func filter(by query: String) -> [TaggedFile] {
        if query.isEmpty {
            return files
        }
        let results = query.split(separator: "|").map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }.map{ $0.split(separator: "&").map{ s in s.trimmingCharacters(in: .whitespacesAndNewlines)} }
        let files = files.filter {
            file in results.anySatisfy {
                conjunction in conjunction.allSatisfy {
                    text in
                    let substr = text[text.index(after: text.startIndex)...]
                    return (text.hasPrefix("!") && !file.tagString.contains(substr) && !file.filename.contains(substr)) || (!text.hasPrefix("!") && ((file.tagString.contains(text) || file.filename.contains(text))))
                }
            }
        }
        cachedFiles = files
        return files
    }
}

extension Array {
    func anySatisfy(_ predicate: (Element) -> Bool) -> Bool {
        !self.allSatisfy { !predicate($0) }
    }
}

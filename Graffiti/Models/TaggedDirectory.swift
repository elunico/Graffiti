//
//  TaggedDirectory.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/2/23.
//

import Foundation

class TaggedDirectory: ObservableObject {
    static let empty: TaggedDirectory = TaggedDirectory()
    
    @Published var directory: String
    var backend: TagBackend
    @Published var files: [TaggedFile] = []
    private var indexMap: [TaggedFile.ID: Int] = [:]
    
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
    
    var allFiles: [TaggedFile] {
        files
    }
    
    func filter(query: String) -> [TaggedFile] {
        files.filter { query.isEmpty || $0.tagString.contains(query) || $0.filename.contains(query) }
    }
    
    
}

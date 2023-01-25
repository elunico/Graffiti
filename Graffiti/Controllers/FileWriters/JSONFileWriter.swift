//
//  JSONFileWriter.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/11/23.
//

import Foundation

class JSONFileWriter: FileWriter {
    func loadFrom(path: String) throws -> TagStore {
        var retValue: [String: Set<Tag>] = [:]
                
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: "{\"version\": \"\(TagStore.default.version.description)\", \"data\": {}}".data(using: .utf8))
        }
        
        let object = try JSONSerialization.jsonObject(with: TPData(contentsOf: URL(filePath: path)))
        
        let dict = object as? [String: Any]
        
        guard let dict else {
            throw FileWriterError.InvalidFileFormat
        }
        
        guard let version = Version(fromDescription: (dict["version"] as? String) ?? "") else {
            throw FileWriterError.InvalidFileFormat
        }
        
        if !version.isReadCompatible(with: TagStore.default.version) {
            throw FileWriterError.VersionMismatch
        }
        
        guard let data = dict["data"] as? [String: [String]] else {
            throw FileWriterError.InvalidFileFormat
        }
        
        for (path, listOfDicts) in data {
            let s: [Tag] = listOfDicts.map { d in Tag(value: d) }
            retValue[path] = Set(s)
        }
        
        return TagStore(tagData: retValue)
    }
    
    func saveTo(path: String, store: TagStore) {
        let data = store.tagData
        var t: [String: [String]] = [:]
        
        for key in data.keys {
            t[key] = data[key].map { c in Array(c) }.map { $0.map { t in t.value }}
        }
        
        let jsonObject = [
            "version" : store.version.description,
            "data": t
        ] as [String : Any]
        
        guard let blob = try? JSONSerialization.data(withJSONObject: jsonObject) else {
            fatalError("Could not convert tag collection to property list data")
        }
        FileManager.default.createFile(atPath: path, contents: blob)
    }
    
    let fileProhibitedCharacters: Set<Character> = Set(["\""])
    
    static let fileExtension: String = ".json"
}

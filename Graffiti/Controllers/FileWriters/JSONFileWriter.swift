//
//  JSONFileWriter.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/11/23.
//

import Foundation

class JSONFileWriter: FileWriter {
    func loadFrom(path: String) throws -> [String : Set<Tag>] {
        var retValue: [String: Set<Tag>] = [:]
                
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: "{}".data(using: .utf8))
        }
        
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(filePath: path)))
        
        let dict = object as? [String: [String]]
        guard let dict else {
            throw FileWriterError.InvalidFileFormat
        }
        
        for (path, listOfDicts) in dict {
            let s: [Tag] = listOfDicts.map { d in Tag(value: d) }
            retValue[path] = Set(s)
        }
        
        
        return retValue
    }
    
    func saveTo(path: String, tags: [String : Set<Tag>]) {
        var t: [String: [String]] = [:]
        
        for key in tags.keys {
            t[key] = tags[key].map { c in Array(c) }.map { $0.map { t in t.value }}
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: t) else {
            fatalError("Could not convert tag collection to property list data")
        }
        FileManager.default.createFile(atPath: path, contents: data)
    }
    
    let fileProhibitedCharacters: Set<Character> = Set(["\""])
    
    let fileExtension: String = ".json"
}

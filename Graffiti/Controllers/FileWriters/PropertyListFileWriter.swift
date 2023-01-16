//
//  JSONFileWriter.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/7/23.
//

import Foundation

class PropertyListFileWriter: FileWriter {
    static let emptyBytes: [UInt8] = [98, 112, 108, 105, 115, 116, 48, 48, 208, 8, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9]

    func loadFrom(path: String) throws -> TagStore {
        var retValue: [String: Set<Tag>] = [:]
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: Data(PropertyListFileWriter.emptyBytes))
        }
        
        
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let object = try PropertyListSerialization.propertyList(from: data, format: nil)
        
        let dict = object as? [String: Any]
        guard let dict else {
            throw FileWriterError.InvalidFileFormat
        }
        
        if dict.keys.count > 0 {
            
            guard let version = dict["version"] as? [String: Int] else {
                print("Could not review version")
                throw FileWriterError.InvalidFileFormat
            }
            
            let cv = TagStore(tagData: [:]).version
            if version["major"] != cv.major || version["minor"] != cv.minor || version["patch"] != cv.patch {
                throw FileWriterError.VersionMismatch
            }
            
            guard let data = dict["tagData"] as? [String: [[String: String]]] else {
                print("Could not get data")
                
                throw FileWriterError.InvalidFileFormat
            }
            
            for (path, listOfDicts) in data {
                let s: [Tag] = listOfDicts.map { d in Tag(value: d[Tag.valueFieldName]!) }
                retValue[path] = Set(s)
            }
        } else {
            return TagStore(tagData: [:])
        }
        
        
        return TagStore(tagData: retValue)
    }
    
    func saveTo(path: String, tags: TagStore) {
        guard let data = try? PropertyListEncoder().encode(tags) else {
            fatalError("Could not convert tag collection to property list data")
        }
        FileManager.default.createFile(atPath: path, contents: data)
    }
    
    let fileProhibitedCharacters: Set<Character> = Set()
        
    let fileExtension: String = ".plist"
        
}

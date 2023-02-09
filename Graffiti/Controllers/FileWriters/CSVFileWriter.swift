//
//  CSVFileWriter.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/7/23.
//

import Foundation

class CSVFileWriter: FileWriter {
   
    static let kTagSeparator: String = ";"
    static let headerRow: String = "path,tags\n"
    
    let fileProhibitedCharacters: Set<Character> = Set([CSVFileWriter.kTagSeparator.first!, ",", "\n"])
       
    static let fileExtension: String = ".csv"
    
    func loadFrom(path: String) throws -> TagStore {
        var retValue: [String: Set<Tag>] = [:]
                
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: (TagStore.default.version.description + "\n" + CSVFileWriter.headerRow).data(using: .utf8))
        }
        
        let string = try String(contentsOfFile: path, encoding: .utf8)
        var lines = string.split(separator: "\n")
        if lines.count == 0 {
            throw FileWriterError.InvalidFileFormat
        }
        // version saved first
        let v = Version(fromDescription: String(lines.remove(at: 0)))
        if v == nil || !TagStore.default.version.isReadCompatible(with: v!) {
            throw FileWriterError.VersionMismatch
        }
        
        // discard header row
        lines.remove(at: 0)
        for line in lines {
            let cols = line.components(separatedBy: ",")
            if cols.count < 2 {
                throw FileWriterError.InvalidFileFormat
            }
            let tags = cols[1].components(separatedBy: CSVFileWriter.kTagSeparator)
//            retValue[cols[0]] = Set(tags.map { Tag(value: $0) })
        }
        return TagStore(tagData: retValue)
    }
    
    func saveTo(path: String, store: TagStore) {
        let data = store.tagData
        let fileContent = store.version.description + "\n" + CSVFileWriter.headerRow + data.map { (path: String, tags: Set<Tag>) in "\(path),\(tags.map { $0.value }.joined(separator: CSVFileWriter.kTagSeparator))" }.joined(separator: "\n")
        FileManager.default.createFile(atPath: path, contents: fileContent.data(using: .utf8))
    }
}

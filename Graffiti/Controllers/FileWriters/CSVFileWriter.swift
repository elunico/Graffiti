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
    
    var fileProhibitedCharacters: Set<Character> {
        Set([CSVFileWriter.kTagSeparator.first!])
    }
    
    var fileExtension: String = ".csv"
    
    func loadFrom(path: String) throws -> [String: Set<Tag>] {
        var retValue: [String: Set<Tag>] = [:]
                
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: CSVFileWriter.headerRow.data(using: .utf8))
        }
        
        let string = try String(contentsOfFile: path, encoding: .utf8)
        var lines = string.split(separator: "\n")
        // discard header row
        lines.remove(at: 0)
        for line in lines {
            let cols = line.components(separatedBy: ",")
            let tags = cols[1].components(separatedBy: CSVFileWriter.kTagSeparator)
            retValue[cols[0]] = Set(tags.map { Tag(value: $0) })
        }
        return retValue
    }
    
    func saveTo(path: String, tags: [String: Set<Tag>]) {
        let fileContent = CSVFileWriter.headerRow + tags.map { (path: String, tags: Set<Tag>) in "\(path),\(tags.map { $0.value }.joined(separator: CSVFileWriter.kTagSeparator))" }.joined(separator: "\n")
        FileManager.default.createFile(atPath: path, contents: fileContent.data(using: .utf8))
    }
}

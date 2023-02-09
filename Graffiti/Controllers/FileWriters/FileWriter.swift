//
//  FileWriter.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/7/23.
//

import Foundation


protocol FileWriter {
    /// any implementation defined characters that cannot appear in tags
    /// This is completely implementation defined. For instance
    /// JSON files could store each tag in its own string so it may prohibit "
    /// from appearing in tags. A JSON implementation could also true to store
    /// all tags in a single string thereby prohibiting " and some other tag
    /// deliminating character. There is no way to say what these characters will be
    /// therefore, without checking this property
    var fileProhibitedCharacters: Set<Character> { get }
    
    /// The String keys of the return value are file paths
    func loadFrom(path: String)  throws -> TagStore
    
    /// The String keys of the second argument are file paths
    func saveTo(path: String, store: TagStore)
    
    /// Should include a period. For instance for CSV files it would be ".csv"
    static var fileExtension: String { get }
    
    /// provides a default path to a writeable file with a default
    /// filename inside the directory `directory`
    /// Default implementation is provided
    static func defaultWritePath(in directory: URL) -> String
    
    /// provides a path to the specified file name in the given directory
    /// Falls back to `defaultWritePath(in:)` if `filename` is nil
    /// Default implementation is provided
    static func writePath(in directory: URL, named filename: String?) -> String
}

extension FileWriter {
    static func defaultWritePath(in directory: URL) -> String {
        "\(directory.absolutePath)\(FileTagBackend.filePrefix)\(Self.fileExtension)"
    }
    
    static func writePath(in directory: URL, named filename: String?) -> String {
        if let filename {
            return "\(directory.absolutePath)\(filename)\(Self.fileExtension)"
        } else {
            return Self.defaultWritePath(in: directory)
        }
    }
}

// TODO: fix plist, csv, and json to have image attributes and recognized text
func convert(file url: URL, isUsing currentWriter: FileWriter, willUse futureWriter: FileWriter)  throws {
    let data = try  currentWriter.loadFrom(path: url.absolutePath)
    let path = url.deletingPathExtension().appendingPathExtension(String(type(of: futureWriter).fileExtension.trimmingPrefix(/\./))).absolutePath
     try  getSandboxedAccess(to: path, thenPerform: {futureWriter.saveTo(path: $0, store: data)})
}

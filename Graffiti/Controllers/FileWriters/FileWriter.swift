//
//  FileWriter.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/7/23.
//

import Foundation

enum FileWriterError: Error {
    case InvalidFileFormat
    case VersionMismatch
}

protocol FileWriter {
    /// The String keys of the return value are file paths
    func loadFrom(path: String) throws -> TagStore
    
    /// The String keys of the second argument are file paths
    func saveTo(path: String, tags: TagStore)
    
    /// provides a default path to a writeable file with a default
    /// filename inside the directory `directory`
    /// Default implementation is provided
    func defaultWritePath(in directory: URL) -> String
    
    /// any implementation defined characters that cannot appear in tags
    /// This is completely implementation defined. For instance
    /// JSON files could store each tag in its own string so it may prohibit "
    /// from appearing in tags. A JSON implementation could also true to store
    /// all tags in a single string thereby prohibiting " and some other tag
    /// deliminating character. There is no way to say what these characters will be
    /// therefore, without checking this property
    var fileProhibitedCharacters: Set<Character> { get }
    
    /// Should include a period. For instance for CSV files it would be ".csv"
    var fileExtension: String { get }
}

extension FileWriter {
    func defaultWritePath(in directory: URL) -> String {
        "\(directory.absolutePath)\(FileTagBackend.filePrefix)\(fileExtension)"
    }
    
    func writePath(in directory: URL, named filename: String) -> String {
        "\(directory.absolutePath)\(filename)\(fileExtension)"
    }
}

//
//  FileWriter.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/7/23.
//

import Foundation

/// Provides a mechanism for saving and loading ``TagStore`` data to and from a file
///
/// This protocol requires conformants to implement the methods necessary to read and write files of a particular type to disk. ``JSONFileWriter`` and ``CompressedCustomTagStoreWriter`` are the only two working examples currently in this program. The protocol provides the main functions ``loadFrom(path:)`` and ``saveTo(path:store:)`` for general file saving and loading. It also other important fields relating to the writing and reading of files such as a valid ``fileExtension``, how to obtain a correct name for a certain directory with ``writePath(in:named:)-7ie4h`` as well as providing callers with a way of validating input using ``fileProhibitedCharacters``
protocol FileWriter {
    /// any implementation defined characters that cannot appear in tags
    /// This is completely implementation defined. For instance
    /// JSON files could store each tag in its own string so it may prohibit "
    /// from appearing in tags. A JSON implementation could also true to store
    /// all tags in a single string thereby prohibiting " and some other tag
    /// deliminating character. There is no way to see what these characters will be
    /// therefore, without checking this property
    ///
    /// **Important implementation detail** The conforming class/struct is **not**
    /// required to check this property before writing or reading. It is
    /// up to the **call site** of ``loadFrom(path:)`` and ``saveTo(path:store:)``
    /// to check this property and prevent prohibited characters from entering the data
    var fileProhibitedCharacters: Set<Character> { get }

    /// The String keys of the return value are file paths
    func loadFrom(path: String) throws -> TagStore

    /// The String keys of the second argument are file paths
    func saveTo(path: String, store: TagStore) throws

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

    static func writePath(in directory: URL, named filename: String?) -> String
    {
        if let filename {
            return "\(directory.absolutePath)\(filename)\(Self.fileExtension)"
        } else {
            return Self.defaultWritePath(in: directory)
        }
    }
}

/// This function should not be necessary if the futureWriter implementation does not list any prohibited characters
/// The `convert` function which uses this **always** uses a `FileTagBackend` which defines illegal
/// characters only based on its writer, so if there are no new illegal characters in the `futureWriter` no additional
/// illegal characters will need to be tested. The `TagBackend` does define illegal characters but they are not
/// allowed to be typed into the application regardless of backend implementation. Therefore, this should not be needed
/// unless the file being converted was edited outside the application or the new `futureWriter` defines illegal
/// characters that were not also defined by the originating `FileWriter`
///
/// Therefore converting between two stores with the same implementationProhibitedCharacters means this check should not be needed
func validateStore(store: TagStore, futureWriter: FileWriter) throws {
    let f = FileTagBackend()
    f.writer = futureWriter
    
    let re = try Regex("[\(f.prohibitedCharacters.map { String($0) }.joined(separator: ""))]")
    for (file, tags) in store.tagData {
        
        if file.firstMatch(of: re) != nil {
            throw TagBackendError.illegalCharacter
        }
        for tag in tags {
            if tag.image == nil && tag.value.firstMatch(of: re) != nil {
                throw TagBackendError.illegalCharacter
            }
            for s in tag.imageTextContent {
                if s.firstMatch(of: re) != nil {
                    throw TagBackendError.illegalCharacter
                }
            }
        }
    }
}

func convert(
    file url: URL, isUsing currentWriter: FileWriter,
    willUse futureWriter: FileWriter
) throws {
    let data = try currentWriter.loadFrom(path: url.absolutePath)
    let path = url.deletingPathExtension().appendingPathExtension(
        String(type(of: futureWriter).fileExtension.trimmingPrefix(/\./))
    ).absolutePath
    
    let original = currentWriter.fileProhibitedCharacters
    let upcoming = futureWriter.fileProhibitedCharacters
    
    // SEE DOC COMMENT FOR EXPLANATION
    if !(original.subtracting(upcoming).count == 0 && upcoming.subtracting(original).count == 0) {
        try validateStore(store: data, futureWriter: futureWriter)
    }
    
    try getSandboxedAccess(
        to: url.deletingLastPathComponent().absolutePath, thenPerform: { _ in
            print("Writing to \(path)")
            try futureWriter.saveTo(path: path, store: data)
        }
    )
}

//
//  CompressedCustomTagStoreWiter.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/19/23.
//

import Foundation
import os

extension Int {
    var bigEndianBytes: Data {
        
        let data: [UInt8] = [(self & 0xff000000) >> 24, (self & 0xff0000) >> 16, (self & 0xff00) >> 8, self & 0xff].map { UInt8($0) }
        return Data(data)
    }
}

extension Data {
    func last(_ n: Int) -> Data {
        assert(subdata(in: 0..<n).allSatisfy { $0 == 0 })
        return self.subdata(in: (count - n)..<count)
    }
    
    func appending(_ value: Data) -> Data {
        var rest = Data()
        rest.append(self)
        rest.append(value)
        return rest
    }
    
}
extension Data.Iterator {
    mutating func nextBEInt() -> Int? {
        guard let m1 = next(), let m2 = next(), let m3 = next(), let m4 = next() else {
            return nil
        }
        return (Int(m1) << 24) | (Int(m2) << 16) | (Int(m3) << 8) | (Int(m4))
    }
    
    mutating func nextBEInt16() -> Int16? {
        guard let m1 = next(), let m2 = next() else {
            return nil
        }
        return  (Int16(m1) << 8) | (Int16(m2))
    }
    
    mutating func next(_ n: Int) -> Data? {
        var d = Data()
        for _ in 0..<n {
            guard let v = next() else { return nil }
            d.append(contentsOf: [v])
        }
        return d
    }
}

extension Version {
    var encodedForCCTS: Data {
        var data = Data()
        data.append(major.bigEndianBytes.last(2))
        data.append(minor.bigEndianBytes.last(2))
        data.append(patch.bigEndianBytes.last(2))
        return data
    }
    
    static func from(dataIterator: inout Data.Iterator) -> Version {
        let major = dataIterator.nextBEInt16()!
        let minor = dataIterator.nextBEInt16()!
        let patch = dataIterator.nextBEInt16()!
        return Version(major: Int(major), minor: Int(minor), patch: Int(patch))
    }
}

/// Format of this file type
/// All data is compressed using lzma before writing to disk
/// All ints are laid out big-endian
/// All strings are utf-8 encoded
///
/// 2 bytes for major version
/// 2 bytes for minor version
/// 2 bytes for patch version
/// 4 bytes number of files in store
/// ---
///   2 bytes path length
///   variable path to file
///   2 bytes number of tags
///   ----
///     2 bytes tag length
///     variable tag bytes
///   ---- repeats indefinitely
/// --- Repeats until EOF
class CompressedCustomTagStoreWriter: FileWriter {
    let fileProhibitedCharacters: Set<Character> = Set()
    static let fileExtension: String = ".ccts"

    
    func loadFrom(path: String) throws -> TagStore {
        var retValue: [String: Set<Tag>] = [:]
        var isDir: ObjCBool = false
        
        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue {
            FileManager.default.createFile(atPath: path, contents: try! Data(NSData(data: TagStore.default.version.encodedForCCTS.appending(0.bigEndianBytes)).compressed(using: .lzma)))
        }
        
        if isDir.boolValue {
            throw FileWriterError.IsADirectory
        }
        
        print("loading from \(path)")
        guard let contents = try? TPData(contentsOf: URL(fileURLWithPath: path)) else {
            throw FileWriterError.DeniedFileAccess
        }
        
        guard let data = try? Data(NSData(data: contents).decompressed(using: .lzma)) else {
            os_log("%s", log: .default, type: .error, "Error at getting data with path \(path)")

            throw FileWriterError.InvalidFileFormat
        }
        
        if data.count < 10 {
            os_log("%s", log: .default, type: .error, "Data formatted incorrectly with \(data.count) bytes")

            throw FileWriterError.InvalidFileFormat
        }
        
        var iter = data.makeIterator()
        let version = Version.from(dataIterator: &iter)
        
        if !TagStore.default.version.isReadCompatible(with: version) {
            os_log("%s", log: .default, type: .error, "Bad version \(version)")

            throw FileWriterError.VersionMismatch
        }
        
        guard let totalFiles = iter.nextBEInt() else { throw FileWriterError.InvalidFileFormat }
        
        for _ in 0..<totalFiles {
            guard let pathLength = iter.nextBEInt16(), let pathData = iter.next(Int(pathLength)), let path = String(data: pathData, encoding: .utf8) else {
                os_log("%s", log: .default, type: .error, "Invalid path length")

                throw FileWriterError.InvalidFileFormat
            }
            retValue[path] = Set()
            guard let tagCount = iter.nextBEInt() else {
                os_log("%s", log: .default, type: .error, "Invalid tag count")
                throw FileWriterError.InvalidFileFormat
            }
            for _ in 0..<tagCount {
                guard let tagLen = iter.nextBEInt16(), let tagData = iter.next(Int(tagLen)), let tag = String(data: tagData, encoding: .utf8) else {
                    os_log("%s", log: .default, type: .error, "Invalid tag length")
                    throw FileWriterError.InvalidFileFormat
                }
                retValue[path]!.insert(Tag(value: tag))
            }
        }
        
        return TagStore(tagData: retValue)
    }
    
    
    
    func saveTo(path: String, store: TagStore) {
        var data = Data()
        data.append(store.version.encodedForCCTS)
        data.append(store.tagData.count.bigEndianBytes)
        print(data)
        
        for (path, tags) in store.tagData {
            let pdata = path.data(using: .utf8)!
            data.append(pdata.count.bigEndianBytes.last(2))
            data.append(pdata)
            data.append(tags.count.bigEndianBytes)
            for tag in tags {
                let tdata = tag.value.data(using: .utf8)!
                data.append(tdata.count.bigEndianBytes.last(2))
                data.append(tdata)
            }
        }
                
        FileManager.default.createFile(atPath: path, contents: try! NSData(data: data).compressed(using: .lzma) as Data)
    }
}


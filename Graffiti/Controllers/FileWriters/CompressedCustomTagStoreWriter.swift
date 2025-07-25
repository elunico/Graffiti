//
//  CompressedCustomTagStoreWiter.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/19/23.
//

import Foundation
import os
import UniformTypeIdentifiers


extension Int {
    var bigEndianBytes: Data {
        
        let data: [UInt8] = [(self & 0xff000000) >> 24, (self & 0xff0000) >> 16, (self & 0xff00) >> 8, self & 0xff].map { UInt8($0) }
        return Data(data)
    }
}

extension UUID {
    var uuidSequence: [UInt8] {
        let id = uuid
        return [id.0, id.1, id.2,  id.3,  id.4,  id.5,  id.6,  id.7,
                id.8, id.9, id.10, id.11, id.12, id.13, id.14, id.15]
    }
}

extension UTType {
    func asDataBytes() -> Data? {
        return Data().appending(sizedString: identifier)
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
    
    func appending(_ bytes: [UInt8]) -> Data {
        var r = Data()
        r.append(self)
        r.append(Data(bytes))
        return r 
    }
    
    func appending(sizedString string: String) -> Data {
        var rest = Data()
        guard let  s = string.data(using: .utf8) else { fatalError("Could not turn string into data")}
        rest.append(self)
        rest.append(s.count.bigEndianBytes)
        rest.append(s)
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
            d.append(v)
        }
        return d
    }
    
    mutating func nextSizedString() -> String? {
        guard let size = nextBEInt() else { return nil }
        guard let sdata = next(size) else { return nil }
        let s = String(data: sdata, encoding: .utf8)
        return s
    }
    
    mutating func nextUUID() -> UUID? {
        let bytes = next(16)
        return (bytes?.withUnsafeBytes {
            ptr in
            return NSUUID(uuidBytes: ptr)
        }) as UUID?
    }
    
    mutating func nextUTType() -> UTType? {
        guard var s = nextSizedString() else { return nil }
        var uttype = UTType(s)
        return uttype
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

class CompressedCustomTagStoreWriter: FileWriter {
    
    let fileProhibitedCharacters: Set<Character> = Set()
    static let fileExtension: String = ".ccts"

    
    func loadFrom(path: String) throws -> TagStore {
        var retValue: [String: Set<Tag>] = [:]
        var isDir: ObjCBool = false
        
        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue {
            FileManager.default.createFile(atPath: path, contents: try! Data(NSData(data: TagStore.default.version.encodedForCCTS.appending(0.bigEndianBytes).appending(0.bigEndianBytes)).compressed(using: .lzma)))
        }
        
        if isDir.boolValue {
            throw FileWriterError.IsADirectory
        }
        
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
        
        guard let totalTags = iter.nextBEInt() else { throw FileWriterError.InvalidFileFormat }
        for _ in 0..<totalTags {
            let _ = try Tag.deserialize(from: &iter)
        }
        
        guard let totalFiles = iter.nextBEInt() else { throw FileWriterError.InvalidFileFormat }
        
        for _ in 0..<totalFiles {
            guard let pathLength = iter.nextBEInt(), let pathData = iter.next(Int(pathLength)), let path = String(data: pathData, encoding: .utf8) else {
                os_log("%s", log: .default, type: .error, "Invalid path length")
                throw FileWriterError.InvalidFileFormat
            }
            retValue[path] = Set()
            guard let tagCount = iter.nextBEInt() else {
                os_log("%s", log: .default, type: .error, "Invalid tag count")
                throw FileWriterError.InvalidFileFormat
            }
            for _ in 0..<tagCount {
                // TODO: store the recognized text and flag
                guard iter.nextBEInt() != nil, let id = iter.nextUUID() else {
                    os_log("%s", log: .default, type: .error, "Invalid tag length")
                    throw FileWriterError.InvalidFileFormat
                }
                if let tag = Tag.tag(fromID: id) {
                    retValue[path]!.insert(tag)
                } else {
                    reportWarning("Missing tag for id \(id)")
                }
            }
        }
        
        return TagStore(tagData: retValue)
    }
    
    
    
    func saveTo(path: String, store: TagStore) throws {
        var data = Data()
        data.append(store.version.encodedForCCTS)
        
        let allTags = store.uniqueTags()
        data.append(allTags.count.bigEndianBytes)
        
        for tag in allTags {
            data.append(try tag.serializeToData())
        }
        
        data.append(store.tagData.count.bigEndianBytes)
        
        for (path, tags) in store.tagData {
            let pdata = path.data(using: .utf8)!
            data.append(pdata.count.bigEndianBytes)
            data.append(pdata)
            data.append(tags.count.bigEndianBytes)
            for tag in tags {
                let tbytes = tag.id.uuidSequence
                let tdata = Data(tbytes)
                    data.append(tdata.count.bigEndianBytes)
                    data.append(tdata)
                
            }
        }
        FileManager.default.createFile(atPath: path, contents: try! NSData(data: data).compressed(using: .lzma) as Data)
    }
}


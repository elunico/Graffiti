//
//  JSONFileWriter.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/11/23.
//

import Foundation

func jsonify(tag: Tag) throws -> [String: Any] {
    if let image = tag.image, tag.imageFormat == .url {
        var object = [
            "type": "IU",
            "url": image.absolutePath,
            "strings": tag.imageTextContent.content,
            "recognitionState": tag.recoginitionState.rawValue,
            "refCount": tag.refCount
        ] as [String: Any]
        return object
    } else if let image = tag.image, tag.imageFormat == .content {
        var object = [
            "type": "BD",
            "dataSrc": try Data(contentsOf: image).base64EncodedString(),
            "strings": tag.imageTextContent.content,
            "recognitionState": tag.recoginitionState.rawValue,
            "refCount": tag.refCount
        ] as [String : Any]
        return object
    } else {
        var object = [
            "type": "SV",
            "value": tag.value,
            "recognitionState": tag.recoginitionState.rawValue,
            "refCount": tag.refCount
        ] as [String: Any]
        return object
    }
}

func jsonify(file: TaggedFile) throws -> [String: Any] {
    var object = [
        "path": file.id,
        "tags": file.tags.map { $0.id }
    ] as [String : Any]
    return object
}

fileprivate typealias JSONTags = [[String: Any]]
fileprivate typealias JSONFiles = [String: [String]]

class JSONFileWriter: FileWriter {
    func loadFrom(path: String) throws -> TagStore {
//        var retValue: [String: Set<Tag>] = [:]
                
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: "{\"version\": \"\(TagStore.default.version.description)\", \"tags\": {}, \"files\": {}}".data(using: .utf8))
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
        
        guard let tags = dict["tags"] as? JSONTags else {
            throw FileWriterError.InvalidFileFormat
        }
        
        for tag in tags {
            let type = tag["type"] as? String
            switch type {
            case nil :
                fatalError("Invalid type string was nil")
            case "SV":
                guard let value = tag["value"] as? String else { throw FileWriterError.InvalidFileFormat }
                _ = Tag.tag(withString: value)
            case "IU":
                guard let s = tag["url"] as? String else { throw FileWriterError.InvalidFileFormat }
                let url = URL(fileURLWithPath: s)
                guard let strings = tag["strings"] as? [String] else { throw FileWriterError.InvalidFileFormat }
                guard let state = tag["recognitionState"] as? Int else { throw FileWriterError.InvalidFileFormat }
                var t = Tag.tag(imageURL: url, format: .url)
                guard let state = Tag.RecognitionState(rawValue: state) else { throw FileWriterError.InvalidFileFormat }
                t.recoginitionState = state 
                t.imageTextContent.content = strings
            case "BD":
                guard let s = tag["data"] as? String else { throw FileWriterError.InvalidFileFormat }
                let content = NSData(base64Encoded: s)! as Data
                let name = try createOwnedImageURL()
                FileManager.default.createFile(atPath: name.absolutePath, contents: content)
                guard let strings = tag["strings"] as? [String] else { throw FileWriterError.InvalidFileFormat }
                guard let state = tag["recognitionState"] as? Int else { throw FileWriterError.InvalidFileFormat }
                var t = Tag.tag(imageURL: name, format: .content)
                guard let state = Tag.RecognitionState(rawValue: state) else { throw FileWriterError.InvalidFileFormat }
                t.recoginitionState = state
                t.imageTextContent.content = strings
            default:
                fatalError("Unknown type \(type!)")
            }
        }
        
        guard let files = dict["files"] as? JSONFiles else {
            throw FileWriterError.InvalidFileFormat
        }
        
        var value = [String: Set<Tag>]()
        for (path, tags) in files {
            value[path] = Set(tags.map { Tag.tag(fromID: $0)! })
        }
        
        return TagStore(tagData: value)
    }
    
    func saveTo(path: String, store: TagStore) {
        let tags = store.uniqueTags()
        
        var object = [
            "version": store.version.description,
            "tags": JSONTags(),
            "files": JSONFiles()
        ] as [String : Any]
        
        for tag in tags {
            var o  = (object["tags"] as! JSONTags)
            o.append(try! jsonify(tag: tag))
            object["tags"] = o
        }

        for (path, tags) in store.tagData {
            var o = (object["files"] as! JSONFiles)
            o[path] = tags.map { $0.id }
            object["files"] = o
        }
        
        FileManager.default.createFile(atPath: path, contents: try! JSONSerialization.data(withJSONObject: object))
    }
    
    let fileProhibitedCharacters: Set<Character> = Set(["\""])
    
    static let fileExtension: String = ".json"
}

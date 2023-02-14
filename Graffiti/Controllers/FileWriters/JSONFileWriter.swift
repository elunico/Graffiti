//
//  JSONFileWriter.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/11/23.
//

import Foundation

func jsonify(tag: Tag) throws -> [String: Any] {
    if let image = tag.image, tag.imageFormat == .url {
        let object = [
            "type": "IU",
            "uuid": tag.id.uuidString,
            "url": image.absolutePath,
            "strings": tag.imageTextContent.content,
            "recognitionState": tag.recoginitionState.rawValue,
            "refCount": tag.refCount
        ] as [String: Any]
        return object
    } else if let image = tag.image, tag.imageFormat == .content {
        let object = [
            "type": "BD",
            "uuid": tag.id.uuidString,
            "dataSrc": try Data(contentsOf: image).base64EncodedString(),
            "strings": tag.imageTextContent.content,
            "recognitionState": tag.recoginitionState.rawValue,
            "refCount": tag.refCount
        ] as [String : Any]
        return object
    } else {
        let object = [
            "type": "SV",
            "uuid": tag.id.uuidString,
            "value": tag.value,
            "recognitionState": tag.recoginitionState.rawValue,
            "refCount": tag.refCount
        ] as [String: Any]
        return object
    }
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
            print("Could not get dict")
            throw FileWriterError.InvalidFileFormat
        }

        guard let version = Version(fromDescription: (dict["version"] as? String) ?? "") else {
            print("could not get version")
            throw FileWriterError.InvalidFileFormat
        }

        if !version.isReadCompatible(with: TagStore.default.version) {
            print("Incompatible version number")
            throw FileWriterError.VersionMismatch
        }

        guard let tags = dict["tags"] as? JSONTags else {
            print("Could not get tags ")
            throw FileWriterError.InvalidFileFormat
        }

        for tag in tags {
            let type = tag["type"] as? String
            switch type {
            case nil :
                fatalError("Invalid type string was nil")
            case "SV":
                guard let uuid = tag["uuid"] as? String else {
                    print("NO UUID")
                    throw FileWriterError.InvalidFileFormat }
                
                
                if let tag = Tag.tag(fromID: UUID(uuidString: uuid)!) {
                    // tag already exists take no action
                } else {
                    guard let value = tag["value"] as? String else {
                        print("No value")
                        throw FileWriterError.InvalidFileFormat }
                    // create the tag
                    _ = Tag(string: value, id: UUID(uuidString: uuid)!)
                }
            case "IU":
                guard let uuid = tag["uuid"] as? String else {
                    print("NO UUID")
                    throw FileWriterError.InvalidFileFormat }
                guard let s = tag["url"] as? String else {
                    print("No url")
                    throw FileWriterError.InvalidFileFormat }
                let url = URL(fileURLWithPath: s)
                guard let strings = tag["strings"] as? [String] else { throw FileWriterError.InvalidFileFormat }
                guard let state = tag["recognitionState"] as? Int else { throw FileWriterError.InvalidFileFormat }
                var t: Tag
                if let tag = Tag.tag(fromID: UUID(uuidString: uuid)!) {
                    t = tag
                } else {
                    // create the tag
                    t = Tag(imageURL: url, format: .url, id: UUID(uuidString: uuid)!)
                }
                guard let state = Tag.RecognitionState(rawValue: state) else { throw FileWriterError.InvalidFileFormat }
                t.recoginitionState = state
                t.imageTextContent.content = strings
            case "BD":
                guard let s = tag["dataSrc"] as? String else {
                    print("No data")
                    throw FileWriterError.InvalidFileFormat }
                let content = NSData(base64Encoded: s)! as Data
                let name = try createOwnedImageURL()
                FileManager.default.createFile(atPath: name.absolutePath, contents: content)
                guard let strings = tag["strings"] as? [String] else { throw FileWriterError.InvalidFileFormat }
                guard let state = tag["recognitionState"] as? Int else { throw FileWriterError.InvalidFileFormat }
                
                guard let uuid = tag["uuid"] as? String else {
                    print("NO UUID")
                    throw FileWriterError.InvalidFileFormat }
                
                
                var t: Tag
                if let tag = Tag.tag(fromID: UUID(uuidString: uuid)!) {
                    t = tag
                } else {
                    // create the tag
                    t = Tag(imageURL: name, format: .content, id: UUID(uuidString: uuid)!)
                }
                
//                var t = Tag.tag(imageURL: name, format: .content)
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
            value[path] = Set(tags.map { Tag.tag(fromID: UUID(uuidString: $0)!)! })
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
            o[path] = tags.map { $0.id.uuidString }
            object["files"] = o
        }

        FileManager.default.createFile(atPath: path, contents: try! JSONSerialization.data(withJSONObject: object))
    }
    
    let fileProhibitedCharacters: Set<Character> = Set(["\""])
    
    static let fileExtension: String = ".json"
}

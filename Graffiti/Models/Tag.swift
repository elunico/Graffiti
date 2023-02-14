//
//  Tag.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/4/23.
//

import Cocoa
import Vision


extension String {
    var tagIDTypePrefix: Substring {
        if count < 2 { return "" }
        return self[self.startIndex..<self.index(startIndex, offsetBy: 2)]
    }
    
    var tagIDContent: Substring {
        if count < 3 { return "" }
        return self[self.index(startIndex, offsetBy: 2)...]
    }
}

class ImageTextContent: Equatable, Hashable, Codable {
    static func == (lhs: ImageTextContent, rhs: ImageTextContent) -> Bool {
        lhs.content == rhs.content
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(content)
    }
    
    var content: [String] = []
}

class Tag : Equatable, Hashable, Codable, Identifiable {
    static let valueFieldName: String = "value"
    private static var registry: [Tag.ID: Tag] = [:]
    private static var stringRegistry: [String: Tag.ID] = [:]
    private static var imageRegistry: [URL: Tag.ID] = [:]
    
    var id: UUID = UUID()
    
    static func == (lhs: Tag, rhs: Tag) -> Bool {
        lhs.id == rhs.id
    }
    
    
    enum ImageFormat: Codable {
        case url, content
    }
    enum RecognitionState: Int, Codable {
        case uninitialized, started, recognized
    }
    enum SerializeTagError : Error {
        case invalidBytes
    }
    enum DeserializeTagError: Error {
        case noPathLength, noPath, noStringCount, noStringLength, noString
        case noImage
        case noState
        case noRefCount
        case noUUID
    }
    
    
    
    var value: String = ""
    var image: URL? = nil
    var imageFormat: ImageFormat = .url
    var recoginitionState : RecognitionState = .uninitialized
    
    var imageTextContent: ImageTextContent = ImageTextContent()
    
    var searchableMetadataString: String {
        if image != nil {
            return imageTextContent.content.joined(separator: " ")
        } else {
            return value
        }
    }
    
    // refCount only cares about TaggedFile references so until the refCount is incremented
    // by the addition of the tag to a file it should not exist
    private(set) var refCount: Int = 0
    
    
    static func deserialize(from iterator: inout Data.Iterator, imageFormat: ImageFormat)  throws -> Tag {
        func intern() throws -> Tag {
//            if let s = String(data: data, encoding: .utf8), let existing = registry[s] { return existing }
            let typeQualifier = Array(iterator.next(2)!)
            
            
            switch typeQualifier {
            case [73, 85]:
                return try deserializeImageURL(content: &iterator)
            case [66, 68]:
                return try deserializeImageContent(content: &iterator)
            case [83, 86]:
                return try deserializeString(content: &iterator)
            default:
                fatalError()
            }
        }
        
        let tag = try intern()
        print(tag.debugDescription)
        return tag
        
    }
    
    private func recreateTag(from string: String) -> Tag? {
        func createTag() -> Tag? {
            let typeQualifier = string.tagIDTypePrefix
            let content = String(string.tagIDContent)
            switch typeQualifier {
            case "IU":
                // TODO: why is this not fileURLWithPath: but the deserialize one is
                return Tag(imageURL: URL(string: content)!, format: .url)
            case "BD":
                let data = Data(base64Encoded: content, options: .ignoreUnknownCharacters)
                guard let ownedURL = try?  createOwnedImageURL() else { return nil }
                guard let _ = try? data?.write(to: ownedURL) else { return nil }
                return Tag(imageURL: ownedURL, format: .content)
            case "SV":
                return Tag(string: content)
            default:
                fatalError()
            }
        }
        
        return createTag()
    }
    
    static func tag(fromID id: Tag.ID) -> Tag? {
        return registry[id]
    }
    
    static func tag(withString string: String) -> Tag {
        if let id = stringRegistry[string], let tag = registry[id] {
            return tag
        } else {
            assert(registry.values.allSatisfy { $0.value != string })
            return Tag(string: string)
        }
    }

    static func tag(imageURL url: URL) -> Tag {
        
        if let id = imageRegistry[url], let tag = registry[id] {
            return tag
        } else {
            assert(Tag.registry.values.allSatisfy { $0.image != url })
            return Tag(imageURL: url, format: .url)
        }
    }
    
    private init(string: String, id: UUID? = nil) {
        self.image = nil
        self.value = string
        if let id {
            self.id = id
        }
        Tag.registry[self.id] = self
        Tag.stringRegistry[string] = self.id
    }
    
    private init(imageURL: URL, format: ImageFormat, id: UUID? = nil) {
        self.image = imageURL
        self.value = imageURL.absolutePath
        self.imageFormat = format
        if let id {
            self.id = id
        }
        Tag.registry[self.id] = self
        Tag.imageRegistry[imageURL] = self.id
    }
    
    @discardableResult
    func acquire() -> Tag {
        refCount += 1
        return self
    }
    
    func relieve() {
        refCount -= 1
        if refCount == 0 {
            print("Tag \(ObjectIdentifier(self)) is no longer referenced and is being freed")
            Tag.registry.removeValue(forKey: self.id)
            if let imageURL = image {
                try! FileManager.default.removeItem(at: imageURL)
            }
        }
    }
    
    deinit {
        print("Deinit of \(String(describing: self))")
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    
    func serializeToData() throws -> Data {
        if image != nil {
            switch imageFormat {
            case .url:
                let imPath = image!.absolutePath.data(using: .utf8)!
                let magic: [UInt8] = [73, 85]
                let pathLength = imPath.count
                let path = imPath
                var data = Data(magic).appending(Data(id.uuidSequence)).appending(pathLength.bigEndianBytes).appending(path)
                let stringCount = imageTextContent.content.count
                data.append(stringCount.bigEndianBytes)
                for string in imageTextContent.content {
                    
                    guard let sdata = string.data(using: .utf8) else {throw SerializeTagError.invalidBytes}
                    let stringLength = sdata.count
                    data.append(stringLength.bigEndianBytes)
                    data.append(sdata)
                }
                data.append(recoginitionState.rawValue.bigEndianBytes)
                data.append(refCount.bigEndianBytes)
                return data
            case .content:
                let magic : [UInt8] = [66, 68]
                let imageData = try TPData(contentsOf: image!)
                let contentLength = imageData.count
                var data = Data(magic).appending(Data(id.uuidSequence)).appending(contentLength.bigEndianBytes).appending(imageData)
                let stringCount = imageTextContent.content.count
                data = data.appending(stringCount.bigEndianBytes)
                for string in imageTextContent.content {
                    let sdata = string.data(using: .utf8)!
                    let stringLength = sdata.count
                    data = data.appending(stringLength.bigEndianBytes).appending(sdata)
                }
                data.append(recoginitionState.rawValue.bigEndianBytes)
                data.append(refCount.bigEndianBytes)
                
                return data
            }
        } else {
            let magic: [UInt8] = [83, 86]
            let vdata = value.data(using: .utf8)!
            var data = Data(magic).appending(Data(id.uuidSequence)).appending(vdata.count.bigEndianBytes).appending(vdata)
            data.append(recoginitionState.rawValue.bigEndianBytes)
            data.append(refCount.bigEndianBytes)
            
            return data
        }
    }
    
    
    
    
    private static func deserilizeRecognizedStrings(count stringCount: Int, fromIterator iter: inout Data.Iterator, to tag: inout Tag) throws {
        for _ in 0..<stringCount {
            guard let stringLength = iter.nextBEInt() else { throw DeserializeTagError.noStringLength }
            guard let stringData = iter.next(stringLength) else { throw DeserializeTagError.noStringLength }
            guard let string = String(data: stringData, encoding: .utf8) else { throw DeserializeTagError.noString }
            tag.imageTextContent.content.append(string)
            
        }
    }
    
    private static func skipRecognizedStrings(count stringCount: Int, fromIterator iter: inout Data.Iterator) throws {
        for _ in 0..<stringCount {
            guard let stringLength = iter.nextBEInt() else { throw DeserializeTagError.noStringLength }
            guard let stringData = iter.next(stringLength) else { throw DeserializeTagError.noStringLength }
            guard String(data: stringData, encoding: .utf8) != nil else { throw DeserializeTagError.noString }
        }
    }
    
    private static func deserializeImageURL(content iter: inout Data.Iterator) throws -> Tag {
        
        guard let id = iter.nextUUID() else { throw DeserializeTagError.noUUID }
        
        guard let pathLength = iter.nextBEInt() else { throw DeserializeTagError.noPathLength }
        
        guard let data = iter.next(pathLength), let path = String(data: data, encoding: .utf8) else { throw DeserializeTagError.noPath }
        guard let stringCount = iter.nextBEInt() else { throw DeserializeTagError.noStringCount }
        
//        var t = Tag.tag(imageURL: URL(fileURLWithPath: path), format: .url)
        var t = Tag(imageURL: URL(fileURLWithPath: path), format: .url, id: id)
        print("Deserializing \(String(reflecting: t))")
        if t.recoginitionState == .uninitialized {
            try deserilizeRecognizedStrings(count: stringCount, fromIterator: &iter, to: &t)
            
            guard let recognitionState = iter.nextBEInt() else { throw DeserializeTagError.noState }
            t.recoginitionState = RecognitionState(rawValue: recognitionState)!
        } else {
            // TODO: Do not store strings for every tag
            try skipRecognizedStrings(count: stringCount, fromIterator: &iter)
            // discard state
            iter.nextBEInt()
        }
        
        guard let rc = iter.nextBEInt() else { throw DeserializeTagError.noRefCount }
        t.refCount = rc

        return t
        
        
    }
    
    private static func deserializeImageContent(content iter: inout Data.Iterator) throws -> Tag {
        guard let id = iter.nextUUID() else { throw DeserializeTagError.noUUID }
        
        guard let pathLength = iter.nextBEInt() else { throw DeserializeTagError.noPathLength}
        
        guard let data = iter.next(pathLength), let imageContent = NSImage(data: data) else { throw DeserializeTagError.noImage }
        
        guard let stringCount = iter.nextBEInt() else { throw DeserializeTagError.noStringCount }
        
        // TODO: name should be persistent to prevent recreating images
        let name = try createOwnedImageURL()
        try data.write(to: name)
        
        var t = Tag(imageURL: name, format: .content, id: id)

        if t.recoginitionState == .uninitialized {
            
            try deserilizeRecognizedStrings(count: stringCount, fromIterator: &iter, to: &t)
            
            guard let recognitionState = iter.nextBEInt() else { throw DeserializeTagError.noState }
            t.recoginitionState = RecognitionState(rawValue: recognitionState)!
        } else {
            // TODO: Do not store strings for every tag
            try skipRecognizedStrings(count: stringCount, fromIterator: &iter)

            // discard state
            iter.nextBEInt()
        }
        guard let rc = iter.nextBEInt() else { throw DeserializeTagError.noRefCount }
        t.refCount = rc
        
        return t
        
        
    }
    
    private static func deserializeString(content iter: inout Data.Iterator) throws -> Tag {
        guard let id = iter.nextUUID() else { throw DeserializeTagError.noUUID }
    
        guard let pathLength = iter.nextBEInt() else { throw DeserializeTagError.noPathLength}
        
        guard let data = iter.next(pathLength), let value = String(data: data, encoding: .utf8) else { throw DeserializeTagError.noPath }
        guard let recognitionState = iter.nextBEInt() else { throw DeserializeTagError.noState }
        
        var t = Tag(string: value, id: id)
        t.recoginitionState = RecognitionState(rawValue: recognitionState)!
        
        guard let rc = iter.nextBEInt() else { throw DeserializeTagError.noRefCount }
        t.refCount = rc

        return t
        
        
    }
    
    
}

extension Tag {

    
    var serializedContentString: String {
        if image == nil {
            return "SV\(value)"
        } else if image != nil && imageFormat == .url {
            return "IU\(image!)"
        } else if image != nil && imageFormat == .content {
            return "BD\(try! Data(contentsOf: image!).base64EncodedString())"
        } else {
            fatalError("Unidentifiable tag")
        }
        
    }
}

extension Tag: CustomStringConvertible {
    var description: String {
        if image != nil {
            return "<image\(imageTextContent.content.count == 0 ? "" : " (\(imageTextContent.content.count) strings)")>"
        } else {
            return value
        }
    }
}

extension Tag: CustomDebugStringConvertible {
    var debugDescription: String {
        "Tag(ref: \(ObjectIdentifier(self)) rc: \(refCount), value: \(value), image: \(image?.lastPathComponent ?? "nil"), state: \(recoginitionState), strings: \(imageTextContent.content))"
    }
    
    
}

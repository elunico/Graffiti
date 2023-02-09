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

class Tag : Equatable, Hashable, Codable {
    static func == (lhs: Tag, rhs: Tag) -> Bool {
        if lhs.image != nil && rhs.image != nil {
            return lhs.image == rhs.image && lhs.imageFormat == rhs.imageFormat && lhs.recoginitionState == rhs.recoginitionState
        } else {
            return lhs.value == rhs.value
        }
    }
    
    func hash(into hasher: inout Hasher) {
        if image != nil {
            hasher.combine(image)
            hasher.combine(imageFormat)
            hasher.combine(recoginitionState)
        } else {
            hasher.combine(value)
        }
    }
    
    var value: String = ""
    var image: URL? = nil
    var imageFormat: ImageFormat = .url
    
    var recoginitionState : RecognitionState = .uninitialized
    
    static let valueFieldName: String = "value"
    
    var imageTextContent: ImageTextContent = ImageTextContent()
    
    var searchableMetadataString: String {
        if image != nil {
            return imageTextContent.content.joined(separator: " ")
        } else {
            return value
        }
    }
    
    enum ImageFormat: Codable {
        case url, content
    }
    enum RecognitionState: Int, Codable {
        case uninitialized, started, recognized
    }
    
    private static var registry: [Tag.ID: Tag] = [:]
    
    static func tag(fromID string: Tag.ID) -> Tag? {
        
        //    convenience init?(fromID string: Tag.ID)  {
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
        
        if let tag = registry[string] {
            return tag
        } else {
            guard let tag = createTag() else { return nil }
            registry[tag.id] = tag
            return tag
        }
    }
    
    static func tag(withString string: String) -> Tag {
        if let tag = registry["SV\(string)"] {
            print("Fonud existing tag")
            return tag
        } else {
            let tag = Tag(string: string)
            registry[tag.id] = tag
            return tag
        }
    }
    
    private init(string: String) {
        self.image = nil
        self.value = string
    }
    
    private init(imageURL: URL, format: ImageFormat) {
        self.image = imageURL
        self.value = imageURL.absolutePath
        self.imageFormat = format
    }
    
    static func tag(imageURL url: URL, format: ImageFormat) -> Tag {
        let tag = Tag(imageURL: url , format: format)

//        let key = format == .content ? "BD\(url.absolutePath)" : "IU\(url.absolutePath)"
        
        if let tag = registry[tag.id] {
            print("Fonud existing tag")
            return tag
        } else {
            registry[tag.id] = tag
            return tag
        }
    }
    
    //    func serializeToString(imageFormat: ImageFormat) throws -> String {
    //        if image != nil {
    //            switch imageFormat {
    //            case .url:
    //                return "IU\(image!.absolutePath)"
    //            case .content:
    //                return "BD\(try TPData(contentsOf: image!).base64EncodedString())"
    //            }
    //        } else {
    //            return "SV\(value)"
    //        }
    //    }
    
    enum SerializeTagError : Error {
        case invalidBytes
    }
    
    func serializeToData(imageFormat: ImageFormat) throws -> Data {
        if image != nil {
            switch imageFormat {
            case .url:
                let imPath = image!.absolutePath.data(using: .utf8)!
                let magic: [UInt8] = [73, 85]
                let pathLength = imPath.count
                let path = imPath
                var data = Data(magic).appending(pathLength.bigEndianBytes).appending(path)
                let stringCount = imageTextContent.content.count
                data.append(stringCount.bigEndianBytes)
                for string in imageTextContent.content {
                    
                    guard let sdata = string.data(using: .utf8) else {throw SerializeTagError.invalidBytes}
                    let stringLength = sdata.count
                    data.append(stringLength.bigEndianBytes)
                    data.append(sdata)
                }
                data.append(recoginitionState.rawValue.bigEndianBytes)
                return data
            case .content:
                let magic : [UInt8] = [66, 68]
                let imageData = try TPData(contentsOf: image!)
                let contentLength = imageData.count
                var data = Data(magic).appending(contentLength.bigEndianBytes).appending(imageData)
                let stringCount = imageTextContent.content.count
                data = data.appending(stringCount.bigEndianBytes)
                for string in imageTextContent.content {
                    let sdata = string.data(using: .utf8)!
                    let stringLength = sdata.count
                    data = data.appending(stringLength.bigEndianBytes).appending(sdata)
                }
                data.append(recoginitionState.rawValue.bigEndianBytes)
                return data
            }
        } else {
            let magic: [UInt8] = [83, 86]
            let vdata = value.data(using: .utf8)!
            var data = Data(magic).appending(vdata.count.bigEndianBytes).appending(vdata)
            data.append(recoginitionState.rawValue.bigEndianBytes)
            return data
        }
    }
    
    //    static func deserialize(from string: String, imageFormat: ImageFormat)  throws -> Tag {
    //        if let existing = registry[string] { return existing }
    //        let typeQualifier = string[string.startIndex..<string.index(string.startIndex, offsetBy: 2)]
    //        let content = String(string[string.index(string.startIndex, offsetBy: 2)...])
    //        switch typeQualifier {
    //        case "IU":
    //            return Tag(string: content)
    //        case "BD":
    //            let data = Data(base64Encoded: content, options: .ignoreUnknownCharacters)
    //            let ownedURL = try  createOwnedImageURL()
    //            try data?.write(to: ownedURL)
    //            return Tag(imageURL: ownedURL, format: .content)
    //        case "SV":
    //            return Tag(imageURL: URL(string: content)!, format: .url)
    //        default:
    //            fatalError()
    //        }
    //
    //    }
    
    
    enum DeserializeTagError: Error {
        case noPathLength, noPath, noStringCount, noStringLength, noString
        case noImage
        case noState
    }
    
    private static func deserilizeRecognizedStrings(count stringCount: Int, fromIterator iter: inout Data.Iterator, to tag: inout Tag) throws {
        for _ in 0..<stringCount {
            guard let stringLength = iter.nextBEInt() else { throw DeserializeTagError.noStringLength }
            print("stringLength \(stringLength)")
            guard let stringData = iter.next(stringLength) else { throw DeserializeTagError.noStringLength }
            print("stringData \(stringData)")
                    guard let string = String(data: stringData, encoding: .utf8) else { throw DeserializeTagError.noString }
            tag.imageTextContent.content.append(string)
        }
    }
    
    private static func deserializeImageURL(content: Data) throws -> Tag {
        
        var iter = content.makeIterator()
        guard let pathLength = iter.nextBEInt() else { throw DeserializeTagError.noPathLength}
        
        guard let data = iter.next(pathLength), let path = String(data: data, encoding: .utf8) else { throw DeserializeTagError.noPath }
        print(path)
        guard let stringCount = iter.nextBEInt() else { throw DeserializeTagError.noStringCount }
        print("Attempting to restore \(stringCount) strings")
        
        var t = Tag.tag(imageURL: URL(fileURLWithPath: path), format: .url)
        
        if t.recoginitionState == .uninitialized {
            try deserilizeRecognizedStrings(count: stringCount, fromIterator: &iter, to: &t)
            
            guard let recognitionState = iter.nextBEInt() else { throw DeserializeTagError.noState }
            t.recoginitionState = RecognitionState(rawValue: recognitionState)!
        }
        
        return t
        
        
    }
    
    private static func deserializeImageContent(content: Data) throws -> Tag {
        
        var iter = content.makeIterator()
        guard let pathLength = iter.nextBEInt() else { throw DeserializeTagError.noPathLength}
        
        guard let data = iter.next(pathLength), let imageContent = NSImage(data: data) else { throw DeserializeTagError.noImage }
        
        guard let stringCount = iter.nextBEInt() else { throw DeserializeTagError.noStringCount }
        
        // TODO: name should be persistent to prevent recreating images
        let name = try createOwnedImageURL()
        try data.write(to: name)
        
        var t = Tag.tag(imageURL: name, format: .content)
        
        if t.recoginitionState == .uninitialized {
            
            try deserilizeRecognizedStrings(count: stringCount, fromIterator: &iter, to: &t)
            
            guard let recognitionState = iter.nextBEInt() else { throw DeserializeTagError.noState }
            t.recoginitionState = RecognitionState(rawValue: recognitionState)!
        }
        
        return t
        
        
    }
    
    private static func deserializeString(content: Data) throws -> Tag {
        
        var iter = content.makeIterator()
        guard let pathLength = iter.nextBEInt() else { throw DeserializeTagError.noPathLength}
        
        guard let data = iter.next(pathLength), let value = String(data: data, encoding: .utf8) else { throw DeserializeTagError.noImage }
        guard let recognitionState = iter.nextBEInt() else { throw DeserializeTagError.noState }
        
        var t = Tag.tag(withString: value)
        t.recoginitionState = RecognitionState(rawValue: recognitionState)!
        return t
        
        
    }
    
    static func deserialize(from data: Data, imageFormat: ImageFormat)  throws -> Tag {
        if let s = String(data: data, encoding: .utf8), let existing = registry[s] { return existing }
        let typeQualifier = Array(data[0..<2])
        let content = Data(data[2...])
        
        switch typeQualifier {
        case [73, 85]:
            return try deserializeImageURL(content: content)
        case [66, 68]:
            return try deserializeImageContent(content: content)
        case [83, 86]:
            return try deserializeString(content: content)
        default:
            fatalError()
        }
        
    }
    
}

extension Tag: Identifiable {
    var id: String {
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


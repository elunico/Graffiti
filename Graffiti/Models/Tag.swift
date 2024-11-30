//
//  Tag.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/4/23.
//

import Cocoa
import Vision
import CoreTransferable

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



/// The `Tag` class represents a `String` or an `NSImage` that tags a particular file
///
/// `Tag` instances are unique across runs of the program. Every file that is
/// tagged with the same `String` or `NSImage` holds a reference to a single `Tag` object
///
/// The `Tag` class manages a registry of objects to distribute to users. There are
/// 6 ways to obtains a `Tag` object, generally broken up into 4 categories
///
/// 1) Calling ``deserialize(from:imageFormat:)`` is done to deserialize a tag
/// from the CCTS file format. When the method is used on data from the CCTS format it is
/// efficient, but it does not check for existing tags before construction so it may construct
/// a new `Tag` and replace an existing instance which destroys the invariants of the `Tag` class.
/// As such this method should only be called on data directly obtained from a CCTS file.
/// Calling `deserialize` twice for the same `Tag` data will break `Tag` invariants. This should never be done. The structure of a CCTS file ensures this does not happen
///
/// 2) Calling an appropriate constructor: either ``init(string:id:)`` or ``init(imageURL:format:id:)``. Like ``deserialize(from:imageFormat:)`` there is a risk of
/// breaking class invariants when using the constructors. They are necessary, however, when constructing a `Tag` with a known id. This occurs on deserialization of non-CCTS file formats where a `UUID` is preserved across saves, since the `UUID` connects files and their tags it must be consistent between loads. These constructors should not be used unless it is **required** that the caller pass a known `UUID` to the tag rather than accept the generated `UUID` provided. If these constructors are called multiple times for the same `String` or `NSImage`, they will break the `Tag` class. To use the constructors care should be taken to first query the `Tag` class for existing `Tag`s with the same data by using the query method ``Tag/tag(fromID:)``. Call this method first to determine if the tag with the given ID already exists, and, only if ``Tag/tag(fromID:)`` returns `  `, is it safe to construct the tag with the given ID. If you need to construct a tag but do not need to specify its ID, use the ``Tag/tag(withString:)`` or ``Tag/tag(imageURL:)`` static methods.
///
/// 3) The ``Tag/tag(withString:)`` or ``Tag/tag(imageURL:)`` static methods. These methods are the safest way to construct new tags because they check for existing tags with that data and only if they are not present do they then construct and return new tags. Prefer these methods as long as they are possible
///
/// 4) The last method has already been mentioned and is ``Tag/tag(fromID:)``. This method does not construct a `Tag` instance at all, but only returns an existing `Tag` with the given ID, if it exists. This is the ideal method to call and can always be called without breaking any aspect of the Tag class, but it does return an `Optional<Tag>` so other methods are, at least in principle, necessary.
final class Tag : Equatable, Hashable, Codable, Identifiable {
    
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
        /* DO NOT USE THIS CASE */
        case none
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
    var thumbnail: URL? = nil
    var imageFormat: ImageFormat = .url
    var recoginitionState : RecognitionState = .uninitialized
    
    var imageTextContent: [String] = []
    
    var searchableMetadataString: String {
        if image != nil {
            return imageTextContent.joined(separator: " ")
        } else {
            return value
        }
    }
    
    // refCount only cares about TaggedFile references so until the refCount is incremented
    // by the addition of the tag to a file it should not exist
    private(set) var refCount: Int = 0
    
    
    /// Deserialize a `Tag` instance from a CCTS file.
    ///
    /// Warning! Using this method comes with serious caveats see the documentation on the ``Tag`` class for more information
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
    
    /// Obtain an existing `Tag` instance from its ID if it exists.
    ///
    /// Warning! Using this method comes with serious caveats see the documentation on the ``Tag`` class for more information
    static func tag(fromID id: Tag.ID) -> Tag? {
        return registry[id]
    }
    
    /// Obtain an existing `Tag` instance from its `String` value if it exists or create it if it doesn't
    ///
    /// Warning! Using this method comes with serious caveats see the documentation on the ``Tag`` class for more information
    static func tag(withString string: String) -> Tag {
        if let id = stringRegistry[string], let tag = registry[id] {
            return tag
        } else {
            assert(registry.values.allSatisfy { $0.value != string })
            return Tag(string: string)
        }
    }

    /// Obtain an existing `Tag` instance from its known `URL` to an Image if it exists or create it if it doesn't
    ///
    /// Warning! Using this method comes with serious caveats see the documentation on the ``Tag`` class for more information
    static func tag(imageURL url: URL, thumbnail: URL? = nil) -> Tag {
        
        if let id = imageRegistry[url], let tag = registry[id] {
            return tag
        } else {
            assert(Tag.registry.values.allSatisfy { $0.image != url })
            return Tag(imageURL: url, format: .url, thumbnail: thumbnail)
        }
    }
    
    /// Construct a new `Tag` instance with a `String` and `UUID`
    ///
    /// Warning! Using this method comes with serious caveats see the documentation on the ``Tag`` class for more information
    init(string: String, id: UUID? = nil) {
        self.image = nil
        self.value = string
        if let id {
            self.id = id
        }
        Tag.registry[self.id] = self
        Tag.stringRegistry[string] = self.id
    }
    
    /// Construct a new `Tag` instance with a Image file `URL` and `UUID`
    ///
    /// Warning! Using this method comes with serious caveats see the documentation on the ``Tag`` class for more information
    init(imageURL: URL, format: ImageFormat, thumbnail: URL? = nil, id: UUID? = nil) {
        self.image = imageURL
        self.value = imageURL.absolutePath
        self.imageFormat = format
        if thumbnail == nil {
            self.thumbnail = try? tryGetThumbnail(for: imageURL)
        } else {
            self.thumbnail = thumbnail
        }
        if let id {
            self.id = id
        }
        Tag.registry[self.id] = self
        Tag.imageRegistry[imageURL] = self.id
    }
    
    /// Indicates the `Tag` is being held by something
    ///
    /// This method is called on a `Tag` instance when it becomes associated with a file. It increment the `refCount` of the `Tag` instance indicating another file holds a reference to this tag. This method must be called when assigning a Tag instance to a file. In general, this method should be called any time any entity is holding a reference to a particular `Tag` instance. Failure to properly call this method will result in `Tag` instances not known to the `Tag` class and images getting deleted from the filesystem
    ///
    /// - Returns: self
    @discardableResult
    func acquire() -> Tag {
        refCount += 1
//        print("Tag \(id) now has rc: \(refCount)")
        return self
    }
    
    /// Indicates the `Tag` is no longer being used
    ///
    /// This method is called on Tags when they are removed from a file. It decrements the `refCount` and, if necessary, removes the `Tag` from the registry that the `Tag` class keeps and, if necessary, removes the associated image file that the `Tag` has. Since this method removes filesystem resources, this method should be called whenever an entity is sure that a tag will not be needed again for the remaining lifetime of the program.
    func relieve() {
        refCount -= 1
        //        print("Tag \(id) now has rc: \(refCount)")
        if refCount == 0 {
            //            print("Tag \(self.id) is no longer needed by any file.")
            Tag.registry.removeValue(forKey: self.id)
            Tag.stringRegistry.removeValue(forKey: self.value)
            Tag.imageRegistry.removeValue(forMaybeKey: self.image)
            if let imageURL = image {
                try? FileManager.default.removeItem(at: imageURL)
            }
            if let thumbnail {
                try? FileManager.default.removeItem(at: thumbnail)
            }
        }
    }
        
    func ensureThumbnail() throws {
        if let image, try tryGetThumbnail(for: image) != nil {
            return
        }
        if let image {
            self.thumbnail = try makeThumbnail(of: image)
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Serializes the Tag to a format appropriate for CCTS files
    ///
    /// This method produces a Data representation of the `Tag` object that is suitable for writing to a CCTS file.
    func serializeToData() throws -> Data {
        if image != nil {
            precondition(imageFormat != .none, "cannot save an image tag with a format of .none")
            switch imageFormat {
            case .none:
                fatalError("I told you not to use it")
            case .url:
                let imPath = image!.absolutePath.data(using: .utf8)!
                let magic: [UInt8] = [73, 85]
                let pathLength = imPath.count
                let path = imPath
                var data = Data(magic).appending(Data(id.uuidSequence)).appending(pathLength.bigEndianBytes).appending(path)
                let stringCount = imageTextContent.count
                data.append(stringCount.bigEndianBytes)
                for string in imageTextContent {
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
                let stringCount = imageTextContent.count
                data = data.appending(stringCount.bigEndianBytes)
                for string in imageTextContent {
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
            tag.imageTextContent.append(string)
            
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
        
        let imageURL = URL(fileURLWithPath: path)

        // if the thumbnail exists for this image, use it, otherwise the Tag.init method will create one from the provided image
        let thumbnail: URL? = try tryGetThumbnail(for: imageURL)
        
        // if thumbnail is nil because no thumbnail exists, one will be created in the init
        var t = Tag(imageURL: imageURL, format: .url, thumbnail: thumbnail, id: id)
        t.imageFormat = .url 
//        print("Deserializing \(String(reflecting: t))")
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
        
        // if the thumbnail exists for this image, use it, otherwise the Tag.init method will create one from the provided image
        var thumbnail: URL? = try tryGetThumbnail(for: name)
        
        // if thumbnail is nil because no thumbnail exists, one will be created in the init
        var t = Tag(imageURL: name, format: .content, thumbnail: thumbnail, id: id)
        t.imageFormat = .content

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

extension Tag: CustomStringConvertible {
    var description: String {
        if image != nil {
            return "<image\(imageTextContent.count == 0 ? "" : " (\(imageTextContent.count) strings)")>"
        } else {
            return value
        }
    }
}

extension Tag: CustomDebugStringConvertible {
    var debugDescription: String {
        "Tag(id: \(self.id.uuidString) rc: \(refCount), value: \(value), image: \(image?.lastPathComponent ?? "nil"), state: \(recoginitionState), strings: \(imageTextContent))"
    }
    
    
}

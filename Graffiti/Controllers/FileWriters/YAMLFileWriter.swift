//
//  YAMLFileWriter.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 12/2/24.
//

import Foundation

import AppKit

func tagToYAML(_ tag: Tag) -> String {
    var s = ""
    if let image = tag.image, tag.imageFormat == .url {
        s += "        type: " + "IU" + "\n"
        s += "        uuid: " + tag.id.uuidString + "\n"
        s += "        url: " + image.absolutePath + "\n"
        s += "        strings: " + tag.imageTextContent.description + "\n"
        s += "        imageID: " + tag.imageIdentifier.uuidString + "\n"
        s += "        imageType: " + getTypeOfImage(url: tag.image!).identifier + "\n"
        s += "        recognitionState: " + tag.recoginitionState.rawValue.description + "\n"
        s += "        refCount: " + tag.refCount.description + "\n"
        return s
    } else if let image = tag.image, tag.imageFormat == .content {
        let d = try! Data(contentsOf: image).base64EncodedString()
        s += "        type: " + "BD" + "\n"
        s += "        uuid: " + tag.id.uuidString + "\n"
        s += "        dataSrc: " + d + "\n"
        s += "        imageID: " + tag.imageIdentifier.uuidString + "\n"
        s += "        imageType: " + getTypeOfImage(url: tag.image!).identifier + "\n"
        s += "        strings: " + tag.imageTextContent.description + "\n"
        s += "        recognitionState: " + tag.recoginitionState.rawValue.description + "\n"
        s += "        refCount: " + tag.refCount.description + "\n"
        return s
    } else {
        s += "        type: " + "SV" + "\n"
        s += "        uuid: " + tag.id.uuidString + "\n"
        s += "        value: " + tag.value + "\n"
        s += "        recognitionState: " + tag.recoginitionState.rawValue.description + "\n"
        s += "        refCount: " + tag.refCount.description + "\n"
        return s
    }
}

class YAMLFileWriter: FileWriter {
    var fileProhibitedCharacters: Set<Character> = Set(["[", "]", "{", "}"])
    
    func loadFrom(path: String) throws -> TagStore {
        modalAlert(NSAlert.Style.critical,
                   message: "Unsupported Read Operation",
                   information: "This application does not support load or editing YAML formatted files. You can convert an existing file to YAML for external use, but you cannot load a YAML file for editing in this program"
        )
#if DEBUG
        fatalError("Trace")
#else
        throw FileWriterError.UnsupportedLoadFormat
#endif
    }
    
    func saveTo(path: String, store: TagStore) throws {
        let tags = store.uniqueTags()
        
        var s = ""
        s += "version: " + store.version.description + "\n"
        s += "tags:\n"
        
        for tag in tags {
            s += "    - \(tag.id.uuidString):\n"
            s += tagToYAML(tag)
        }
        
        s += "files:\n"
        
        for (path, tags) in store.tagData {
            s += "    - \(path): [\(tags.map{$0.id.uuidString}.joined(separator: ", "))]\n"
        }

        FileManager.default.createFile(atPath: path, contents: s.data(using: .utf8))
    }
    
    static let fileExtension: String = ".yaml"
}

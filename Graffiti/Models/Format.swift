//
//  Format.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/23/23.
//

import UniformTypeIdentifiers
import Foundation

enum Format: Hashable, CustomStringConvertible, CaseIterable {
    var description: String {
        switch self {
        case .ccts: return "Custom Compressed Tag Store"
        case .json: return "JSON File"
        case .yaml: return "YAML File"
        case .none: return "<<none>>"
        }
    }
    
    var contentType: UTType? {
        switch self {
        case .none: return nil
        case .json: return UTType.json
        case .yaml: return UTType.yaml
        case .ccts: return UTType("com.tom.ccts")
        }
    }
    
    var fileExtension: String? {
        switch self {
        case .none: return nil
        case .json: return "json"
        case .ccts: return "ccts"
        case .yaml: return "yaml"
        }
    }
    
    var writer: FileWriter? {
        switch self {
        case .none:
            return nil
        case .json:
            return JSONFileWriter()
        case .ccts:
            return CompressedCustomTagStoreWriter()
        case .yaml:
            return YAMLFileWriter()
        }
    }
    
    func implementation(in directory: URL, withFileName filename: String? = nil) throws -> TagBackend? {
        if self == .none {
            return nil 
        } else {
            return try FileTagBackend(withFileName: filename, forFilesIn: directory, writer: self.writer!)
        }
    }
    
    static func format(forExtension fileExtension: String) -> Format? {
        for format in Format.allCases {
            if format.fileExtension == fileExtension {
                return format
            }
        }
        return nil 
    }
    
    case ccts, json, yaml
    case none
}

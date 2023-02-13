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
        case .none: return "<<none>>"
        }
    }
    
    var contentType: UTType? {
        switch self {
        case .none: return nil
        case .json: return UTType("public.json")
        case .ccts: return UTType("com.tom.ccts")
        }
    }
    
    var fileExtension: String? {
        switch self {
        case .none: return nil
        case .json: return "json"
        case .ccts: return "ccts"
        }
    }
    
    func implementation(in directory: URL, withFileName filename: String? = nil) throws -> TagBackend? {
        var b: TagBackend? = nil

        switch self {
        case .none:
            return nil
        case .json:
            b = try FileTagBackend(withFileName: filename, forFilesIn: directory, writer: JSONFileWriter())
        case .ccts:
            b = try FileTagBackend(withFileName: filename, forFilesIn: directory, writer: CompressedCustomTagStoreWriter())
        }
        return b
    }
    
    static func format(forExtension fileExtension: String) -> Format? {
        for format in Format.allCases {
            if format.fileExtension == fileExtension {
                return format
            }
        }
        return nil 
    }
    
    case ccts, json
    case none
}

//
//  Format.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/23/23.
//

import Foundation

enum Format: Hashable, CustomStringConvertible, CaseIterable {
    var description: String {
        switch self {
        case .plist: return "Property List"
        case .csv: return "Comma-Separated Values"
        case .xattr: return "Extended File Attributes"
        case .json: return "JSON File"
        case .ccts: return "Custom Compressed Tag Store"
        case .none: return "<<none>>"
        }
    }
    
    var fileExtension: String? {
        switch self {
        case .plist: return "plist"
        case .csv: return "csv"
        case .json: return "json"
        case .xattr: return nil
        case .none: return nil
        case .ccts: return "ccts"
        }
    }
    
    func implementation(in directory: URL, withFileName filename: String? = nil) throws -> TagBackend? {
        var b: TagBackend? = nil

        switch self {
        case .none:
            return nil
        case .plist:
            b = try FileTagBackend(withFileName: filename, forFilesIn: directory, writer: PropertyListFileWriter())
        case .csv:
            b = try FileTagBackend(withFileName: filename, forFilesIn: directory, writer: CSVFileWriter())
        case .xattr:
            b = XattrTagBackend()
        case .json:
            b = try FileTagBackend(withFileName: filename, forFilesIn: directory, writer: JSONFileWriter())
        case .ccts:
            b = try FileTagBackend(withFileName: filename, forFilesIn: directory, writer: CompressedCustomTagStoreWriter())
        }
        return b
    }
    
    case xattr, csv, plist, json, ccts
    case none
}

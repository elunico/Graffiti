//
//  FileWriterError.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/28/23.
//

import Foundation

enum FileWriterError: Error {
    case InvalidFileFormat
    case VersionMismatch
    case DeniedFileAccess
    case IsADirectory
    case UnsupportedLoadFormat
}

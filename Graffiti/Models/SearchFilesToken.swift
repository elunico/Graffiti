//
//  SearchFilesToken.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 6/16/25.
//

import Foundation

enum SearchFilesToken: Identifiable, CustomStringConvertible {
    case Untagged, Tagged
    
    case Image, String
    
    var id: Self {
        self
    }
    
    var description: String {
        switch self {
        case .Tagged: "Tagged"
        case .Untagged: "Untagged"
        case .Image: "Image"
            case .String: "String"
        }
    }
}

//
//  Version.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/15/23.
//

import Foundation

struct Version: Equatable, Hashable, Codable, Identifiable, CustomStringConvertible {
  
    typealias ID = String
    
    var id: String {
        "\((major, minor, patch))"
    }
    
    var description: String {
        "v\(major).\(minor).\(patch)"
    }
    
    let major: Int, minor: Int, patch: Int
    
    
    
}

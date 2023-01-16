//
//  TagStore.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/15/23.
//

import Foundation

struct TagStore: Equatable, Hashable, Codable {
    var version: Version = Version(major: 2, minor: 0, patch: 0)
    
    var tagData: [String: Set<Tag>] 
    
    
}

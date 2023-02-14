//
//  TagStore.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/15/23.
//

import Foundation

struct TagStore: Equatable, Hashable, Codable {
    var version: Version = Version(major: 9, minor: 0, patch: 0)
    
    var tagData: [String: Set<Tag>]
    
    static let `default`: TagStore = TagStore(tagData: [:])
}

extension TagStore {
    func uniqueTags() -> [Tag] {
        tagData.values.flatMap { $0 }.unique()
    }
}

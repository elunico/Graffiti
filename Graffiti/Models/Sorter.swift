//
//  Sorter.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/20/23.
//

import Foundation

class Sorter: SortComparator {
    typealias Compared = TaggedFile
    
    static func == (lhs: Sorter, rhs: Sorter) -> Bool {
        lhs.order == rhs.order
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(order)
    }
    
    var order: SortOrder = .forward
    var transform: (TaggedFile) -> String
    
    init(keypath: KeyPath<TaggedFile, String>) {
        self.transform = { $0[keyPath: keypath] }
    }
    
    init(transform: @escaping (TaggedFile) -> String)  {
        self.transform = transform
    }
    
    func compare(_ lhs: TaggedFile, _ rhs: TaggedFile) -> ComparisonResult {
        if order == .forward {
            return transform(lhs).localizedCaseInsensitiveCompare(transform(rhs))
        } else {
            return transform(rhs).localizedCaseInsensitiveCompare(transform(lhs))
        }
    }
}

//
//  Tag.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/4/23.
//

import Foundation

struct Tag : Equatable, Hashable, Codable {
    static let valueFieldName: String = "value"
    
    let value: String
}

extension Tag: Identifiable {
    var id: String { value }
}

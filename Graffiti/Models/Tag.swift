//
//  Tag.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/4/23.
//

import Foundation

struct Tag : Equatable, Hashable, Identifiable, Codable {
    var id: UUID = UUID()
    let value: String
}

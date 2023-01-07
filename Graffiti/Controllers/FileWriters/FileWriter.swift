//
//  FileWriter.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/7/23.
//

import Foundation

protocol FileWriter {
    func loadFrom(path: String) throws -> [String: Set<Tag>]
    
    func saveTo(path: String, tags: [String: Set<Tag>])
    
    var fileProhibitedCharacters: Set<Character> { get }
    var fileExtension: String { get }
}

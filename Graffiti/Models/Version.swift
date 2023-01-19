//
//  Version.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/15/23.
//

import Foundation

struct Version: Equatable, Hashable, Comparable, Codable, Identifiable, CustomStringConvertible {
    static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.major == rhs.major {
            if lhs.minor == rhs.minor {
                return lhs.patch < rhs.patch
            }
            return lhs.minor < rhs.minor
        }
        return lhs.major < rhs.major
    }
    
    func isReadCompatible(with other: Version) -> Bool {
        major == other.major
    }
    
    func isWriteCompatible(with other: Version) -> Bool {
        major == other.major && minor == other.minor
    }
    
  
    typealias ID = String
    
    var id: String {
        "\((major, minor, patch))"
    }
    
    var description: String {
        "v\(major).\(minor).\(patch)"
    }
    
    let major: Int, minor: Int, patch: Int
    
    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    init?(fromDescription description: String) {
        if description[description.startIndex] != "v" {
            return nil
        }
        let parts = description[description.index(after: description.startIndex)...].components(separatedBy: ".").map({ Int($0) })
        guard parts.count == 3, let major = parts[0], let minor = parts[1], let patch = parts[2] else { return nil }
        self.major = major
        self.minor = minor
        self.patch = patch
    }
}

//
//  ArrayUtilities.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/16/23.
//

import Foundation


extension Sequence {
    func also(_ action: (Element) -> ()) -> Self {
        for elt in self {
            action(elt)
        }
        return self
    }
}

extension Array {
    func anySatisfy(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
        for element in self {
            if try predicate(element) {
                return true
            }
        }
        return false
    }
}

extension Array where Element: Sequence {
    func flatten() -> Array<Element.Element> {
        var result = [Element.Element]()
        for elt in self {
            for item in elt {
                result.append(item)
            }
        }
        return result
    }
}

extension Array where Element: Hashable {
    func unique() -> Array<Element> {
        var result = [Element]()
        var checker = Set<Element>()
        for elt in self {
            if !checker.contains(elt) {
                result.append(elt)
                checker.insert(elt)
            }
        }
        return result
    }
}

extension Array where Element: Equatable {
    func allSame() -> Bool {
        count <= 1 || self[1..<endIndex].allSatisfy { $0 == first }
    }
}

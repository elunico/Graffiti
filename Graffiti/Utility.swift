//
//  Utility.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/22/23.
//

import Foundation
import AppKit

protocol AnyOptional {
    associatedtype Element
    var asOptional: Optional<Element> { get }
}

extension Optional: AnyOptional {
    var asOptional: Optional<Wrapped> { self }
}

extension Array where Element: AnyOptional {
    func droppingNils() -> [Element.Element] {
        self.map { $0.asOptional }.filter { $0 != nil }.map { $0! }
    }
}

extension UserDefaults {
    static var this: UserDefaults? {
        UserDefaults(suiteName: "com.tom.graffiti")
    }
}

extension String {
    var lastPathComponent: String {
        (self as NSString).lastPathComponent
    }
}

extension URL {
    var absolutePath: String {
        absoluteString.replacingOccurrences(of: "file://", with: "")
    }
    
    var prettyPrinted: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return absolutePath.replacingOccurrences(of: home.absolutePath, with: "~/")
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

enum FileError: Error {
    case userCancelled, permissionRequested, couldNotRead
}

fileprivate var didRequestPermission: Set<String> = []

func getSandboxedAccess<R>(to directory: String, thenPerform action: (String) throws -> (R)) rethrows -> R {
    do {
        return try action(directory)
    } catch _ where !didRequestPermission.contains(directory) {
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.directoryURL = URL(fileURLWithPath: directory)
        panel.message = "Select the folder you are targeting to grant Graffiti permission to access it"
        let response = panel.runModal()
        // TODO: save bookmark so permissions is only requested once
        if response == NSApplication.ModalResponse.OK {
            didRequestPermission.insert(directory)
            return try action(panel.url!.absolutePath)
        }
        throw FileError.userCancelled
    } catch let error {
        throw error
    }
}

func getContentsOfDirectory(atPath directory: String) throws -> [String] {
    try getSandboxedAccess(to: directory) { try FileManager.default.contentsOfDirectory(atPath: $0) }
}

func TPData(contentsOf url: URL) throws -> Data {
    try Data(contentsOf: url)
}

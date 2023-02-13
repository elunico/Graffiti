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

extension UserDefaults {
    static var thisAppDomain: UserDefaults? {
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
        let s = absoluteString.replacingOccurrences(of: "file://", with: "")
        return s.removingPercentEncoding ?? s
    }
    
    var prettyPrinted: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return absolutePath.replacingOccurrences(of: home.absolutePath, with: "~/")
    }
}

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

enum FileError: Error {
    case userCancelled, permissionRequested, couldNotRead, fileDirectoryMismatch
}

fileprivate var didRequestPermission: Set<String> = []
fileprivate var bookmarks: [URL: Data] = [:]
var bookmarksPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.applicationSupportDirectory, .userDomainMask, true).first!

@discardableResult
func saveBookmark(of url: URL) throws -> Bool {
    let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    bookmarks[url] = data
    return NSKeyedArchiver.archiveRootObject(bookmarks, toFile: bookmarksPath)
}

func accessBookmark(of url: URL) throws -> URL? {
    guard let bookmarks = NSKeyedUnarchiver.unarchiveObject(withFile: bookmarksPath) as? [URL: Data] else { return nil }
    guard let data = bookmarks[url] else { return nil }
    var isStale = false
    let newURL = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
    return newURL
}


func getSandboxedAccess<R>(to directory: String, thenPerform action: (String)  throws -> (R))  throws -> R {
    do {
        let bookmarkedURL = try accessBookmark(of: URL(fileURLWithPath: directory))
        defer { bookmarkedURL?.stopAccessingSecurityScopedResource() }
        bookmarkedURL?.startAccessingSecurityScopedResource()
        return try  action(directory)
    } catch _ where !didRequestPermission.contains(directory) {
        var result: R? = nil
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.directoryURL = URL(fileURLWithPath: directory)
        panel.message = "Select the folder you are targeting to grant Graffiti permission to access it"
        let response = panel.runModal()
        if response == NSApplication.ModalResponse.OK {
            // TODO: save bookmark so permissions is only requested once
            try saveBookmark(of: panel.url!)
            didRequestPermission.insert(directory)
            result = try  action(panel.url!.absolutePath)
        }
        
        
        if result == nil {
            throw FileError.userCancelled
        } else {
            return result!
        }
        
    } catch let error {
        throw error
    }
}


func getContentsOfDirectory(atPath directory: String)  throws -> [String] {
    try  getSandboxedAccess(to: directory) { try FileManager.default.contentsOfDirectory(atPath: $0) }
}

func TPData(contentsOf url: URL) throws -> Data {
    try getSandboxedAccess(to: url.absolutePath) { try Data(contentsOf: URL(fileURLWithPath: $0)) }
}

func createOwnedImageURL()  throws -> URL {
    let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.applicationSupportDirectory, .userDomainMask, true).first!
    let name = UUID()
    let imageDirectory = URL(fileURLWithPath: path).appending(path: "ownedImages")
    
    return try  getSandboxedAccess(to: imageDirectory.absolutePath, thenPerform: { imageDirectoryString in
        let imageDirectory = URL(fileURLWithPath: imageDirectoryString)
        var ownedURL = imageDirectory.appending(path: name.uuidString)
        
        var isdir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: imageDirectory.absolutePath, isDirectory: &isdir)
        if exists {
            if !isdir.boolValue {
                throw FileError.fileDirectoryMismatch
            }
        } else if !exists {
            try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        }
        
        return ownedURL
    })
    
}

func takeOwnership(of file: URL)  throws -> URL {
    
    let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.applicationSupportDirectory, .userDomainMask, true).first!
    let name = file.lastPathComponent
    let imageDirectory = URL(fileURLWithPath: path).appending(path: "ownedImages")
    
    return try  getSandboxedAccess(to: imageDirectory.absolutePath, thenPerform: { imageDirectoryString in
        let imageDirectory = URL(fileURLWithPath: imageDirectoryString)
        var ownedURL = imageDirectory.appending(path: name)
        
        var isdir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: imageDirectory.absolutePath, isDirectory: &isdir)
        if exists {
            if !isdir.boolValue {
                throw FileError.fileDirectoryMismatch
            }
        } else if !exists {
            try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        }
        
        if FileManager.default.fileExists(atPath: ownedURL.absolutePath) {
            let temporaryName = try createOwnedImageURL()
            try FileManager.default.copyItem(at: file, to: temporaryName)
            ownedURL = try FileManager.default.replaceItemAt(ownedURL, withItemAt: temporaryName) ?? ownedURL
        } else {
            try FileManager.default.copyItem(at: file, to: ownedURL)
        }
        
        return ownedURL
    })
    
    
}



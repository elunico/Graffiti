//
//  FileUtilities.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/16/23.
//

import Foundation
import CoreSpotlight
import AppKit

func getContentsOfDirectory(atPath directory: String)  throws -> [String] {
    try  getSandboxedAccess(to: directory) { try FileManager.default.contentsOfDirectory(atPath: $0) }
}

func TPData(contentsOf url: URL) throws -> Data {
//    try getSandboxedAccess(to: url.absolutePath) {
    try Data(contentsOf: URL(fileURLWithPath: url.absolutePath))
//    }
}

func createOwnedImageURL(in directory: String = "ownedImages")  throws -> URL {
    let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.applicationSupportDirectory, .userDomainMask, true).first!
    let name = UUID()
    let imageDirectory = URL(fileURLWithPath: path).appending(path: directory)
    
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

private func ensureExistance(ofDirectory directory: URL) throws {
    var isdir: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: directory.absolutePath, isDirectory: &isdir)
    if exists {
        if !isdir.boolValue {
            throw FileError.fileDirectoryMismatch
        }
    } else if !exists {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

func copyWithReplacement(at source: URL, to destination: URL) throws -> URL {
    if FileManager.default.fileExists(atPath: destination.absolutePath) {
        let temporaryName = try createOwnedImageURL()
        try FileManager.default.copyItem(at: source, to: temporaryName)
        return try FileManager.default.replaceItemAt(destination, withItemAt: temporaryName) ?? destination
    } else {
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }
}

func resize(size: NSSize, toLongest longest: CGFloat) -> NSSize {
    let oldWidth = size.width
    let oldHeight = size.height
    
    if oldWidth > oldHeight {
        // longest is width
        let newWidth = longest
        let newHeight = (oldHeight / oldWidth) * newWidth
        return NSSize(width: newWidth, height: newHeight)
    } else {
        let newHeight = longest
        let newWidth = (oldWidth / oldHeight) * newHeight
        return NSSize(width: newWidth, height: newHeight)
    }
}

func tryGetThumbnail(for imageURL: URL) throws -> URL? {
    let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.applicationSupportDirectory, .userDomainMask, true).first!
    let imageDirectory = URL(fileURLWithPath: path).appending(path: "ownedImages-tiny")
    let filename = imageURL.lastPathComponent
    
//    return try getSandboxedAccess(to: imageDirectory.absolutePath, thenPerform: { imageDirectoryString in
//        let imageDirectory = URL(fileURLWithPath: imageDirectoryString)
        let thumbnail = imageDirectory.appending(path: filename)
        print(thumbnail)
        if FileManager.default.fileExists(atPath: thumbnail.absolutePath) {
            return thumbnail
        } else {
            return nil
        }
//    })
}

func resizeImage(source: NSImage, newSize: NSSize, callback: @MainActor @escaping (_ newImage: NSImage) -> ()) {
    DispatchQueue.global(qos: .userInitiated).async {
        let smallImage = NSImage(size: newSize)
        smallImage.lockFocus()
        source.size = newSize
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(at: .zero, from: NSRect(origin: .zero, size: newSize), operation: .copy, fraction: 1.0)
        smallImage.unlockFocus()
        DispatchQueue.main.async {
            callback(smallImage)
        }
    }
}

func makeThumbnail(of file: URL, longestSize: CGFloat = 200.0) throws -> URL {
    let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.applicationSupportDirectory, .userDomainMask, true).first!
    let imageDirectory = URL(fileURLWithPath: path).appending(path: "ownedImages-tiny")
    let filename = file.lastPathComponent
    
    return try  getSandboxedAccess(to: imageDirectory.absolutePath, thenPerform: { imageDirectoryString in
        let imageDirectory = URL(fileURLWithPath: imageDirectoryString)
        try ensureExistance(ofDirectory: imageDirectory)
        
        guard let i = NSImage(contentsOf: file) else { print("makeThumbnail(of:) failed to load NSImage from \(file)"); throw FileError.couldNotRead  }
        let url = imageDirectory.appending(path: filename) // try createOwnedImageURL(in: "ownedImages-tiny")

        
        let newSize = resize(size: i.size, toLongest: longestSize)
        resizeImage(source: i, newSize: newSize) { smallImage in
            FileManager.default.createFile(atPath: url.absolutePath, contents: smallImage.tiffRepresentation)
        }
        return url
    })
}

func acquireImage(at file: URL) throws -> (imageFile: URL, thumbnailFile: URL) {
    
    let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.applicationSupportDirectory, .userDomainMask, true).first!
    let name = file.lastPathComponent
    let imageDirectory = URL(fileURLWithPath: path).appending(path: "ownedImages")
    
    return try  getSandboxedAccess(to: imageDirectory.absolutePath, thenPerform: { imageDirectoryString in
        let imageDirectory = URL(fileURLWithPath: imageDirectoryString)
        try ensureExistance(ofDirectory: imageDirectory)
        
        var ownedURL = imageDirectory.appending(path: name)
        ownedURL = try copyWithReplacement(at: file, to: ownedURL)
        
        let thumbnail = try makeThumbnail(of: ownedURL)
        
        return (ownedURL, thumbnail)
    })
}

func creationDate(of file: URL) -> Date {
    (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
}

func pruneThumbnailCache(maxCount: Int = 0) throws {
    let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.applicationSupportDirectory, .userDomainMask, true).first!
    let imageDirectory = URL(fileURLWithPath: path).appending(path: "ownedImages-tiny")
    
    if maxCount > 0 {
        var content = try FileManager.default.contentsOfDirectory(at: imageDirectory, includingPropertiesForKeys: [.creationDateKey, .pathKey])
        var count = content.count
        if count <= maxCount { return }
        
        // reversed sort by creation date so oldest ones go first 
        content.sort(by: { creationDate(of: $0) > creationDate(of: $1) })
        var index = content.endIndex - 1
        while count > maxCount {
            try FileManager.default.removeItem(atPath: content[index].absolutePath)
            index -= 1
            count -= 1
        }
    } else {
        try FileManager.default.removeItem(at: imageDirectory)
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
    }
}


enum FileError: Error {
    case userCancelled, permissionRequested, couldNotRead, fileDirectoryMismatch
}

fileprivate var didRequestPermission: Set<String> = []
fileprivate var bookmarks: [URL: Data] = [:]
var bookmarksPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.applicationSupportDirectory, .userDomainMask, true).first!

var mdCache: [String: String] = [:]

func getMDKind(ofFileAtPath path: String) -> String? {
    if let existing = mdCache[path] {
//        print("Cache hit for \(path): \(existing)")
        return existing
    }
    if let mditem = MDItemCreate(nil, path as CFString),
       let mdnames = MDItemCopyAttributeNames(mditem),
       let mdattrs = MDItemCopyAttributes(mditem, mdnames) as? [String:Any],
       let mdkind = mdattrs[kMDItemKind as String] as? String {
        mdCache[path] = mdkind
        return mdkind
    } else {
        return nil
    }
}

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

func selectFolder(callback: @escaping ([URL]) -> ()) {
    
    let folderChooserPoint = CGPoint(x: 0, y: 0)
    let folderChooserSize = CGSize(width: 500, height: 600)
    let folderChooserRectangle = CGRect(origin: folderChooserPoint, size: folderChooserSize)
    let folderPicker = NSOpenPanel(contentRect: folderChooserRectangle, styleMask: .utilityWindow, backing: .buffered, defer: true)
    
    folderPicker.canChooseDirectories = true
    folderPicker.canChooseFiles = false
    folderPicker.allowsMultipleSelection = false
    folderPicker.canDownloadUbiquitousContents = true
    folderPicker.canResolveUbiquitousConflicts = true
    
    folderPicker.begin { response in
        if response == .OK {
            callback(folderPicker.urls)
        }
    }
}

func selectFile(ofTypes types: [UTType], callback: @escaping ([URL]) -> ()) {
    
    let folderChooserPoint = CGPoint(x: 0, y: 0)
    let folderChooserSize = CGSize(width: 500, height: 600)
    let folderChooserRectangle = CGRect(origin: folderChooserPoint, size: folderChooserSize)
    let filePicker = NSOpenPanel(contentRect: folderChooserRectangle, styleMask: .utilityWindow, backing: .buffered, defer: true)
    
    filePicker.canChooseDirectories = false
    filePicker.canChooseFiles = true
    filePicker.allowsMultipleSelection = false
    filePicker.canDownloadUbiquitousContents = true
    filePicker.canResolveUbiquitousConflicts = true
    filePicker.allowedContentTypes = types
    
    filePicker.begin { response in
        if response == .OK {
            callback(filePicker.urls)
        }
    }
}

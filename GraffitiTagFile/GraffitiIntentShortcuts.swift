//
//  GraffitiIntentShortucts.swift
//  GraffitiTagFile
//
//  Created by Thomas Povinelli on 1/24/23.
//

import Foundation
import AppIntents
import os 

struct LibraryAppShorcuts: AppShortcutsProvider {
    @AppShortcutsBuilder static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: GraffitiAddTagsToFile(), phrases: ["Add a tag to the given file by adding it to the specified tag store using \(.applicationName)"])
        AppShortcut(intent: GraffitiGetTagsOfFile(), phrases: ["Get the tags of a given file from the specified tag store using \(.applicationName) and return them as a list of strings"])
    }
}


struct StoreFormatOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        Format.allCases.map { $0.description }
    }
}

extension AppIntent {
    
    func setup(storageType: IntentParameter<String>, file: IntentParameter<IntentFile>) throws -> (TaggedDirectory, TaggedFile, TagBackend) {
        guard let format = Format.allCases.first(where: { $0.description == storageType.wrappedValue })
        else { throw storageType.needsValueError("Choose a tag storage type") }
        
        // TODO: shortcut intent is denied access due to sandbox but sandboxing is disabled
        os_log("%s", log: .default, type: .error, file.wrappedValue.fileURL!.deletingLastPathComponent().absolutePath)
        guard let w = try format.implementation(in: file.wrappedValue.fileURL!.deletingLastPathComponent()) else {
            throw file.needsValueError()
        }
        
        let d = TaggedDirectory.empty.copy() as! TaggedDirectory
        guard (try? d.load(directory: file.wrappedValue.fileURL!.deletingLastPathComponent().absolutePath, backend: w)) != nil else {
            throw FileError.couldNotRead
        }
        
        guard let tagFile = d.getFile(withID: file.wrappedValue.fileURL!.absolutePath) else {
            throw file.needsValueError()
        }
        
        return (d, tagFile, w)
    }
}

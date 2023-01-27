//
//  GraffitiRemoveTagsFromFile.swift
//  GraffitiTagFile
//
//  Created by Thomas Povinelli on 1/24/23.
//

import Foundation
import AppIntents

struct GraffitiRemoveTagsFromFile: AppIntent {
    static var title: LocalizedStringResource = "Remove tags from a File"
    
    static var description: IntentDescription = IntentDescription("Remove the specified tags from the given file in the specified tag store. If the tag does not exist on the file, no action is taken")
    
    @Parameter(title: "File")
    var file: IntentFile
    
    @Parameter(title: "Tags")
    var tags: [String]
    
    @Parameter(title: "Storage Type", optionsProvider: StoreFormatOptionsProvider())
    var storageType: String
    
    func perform() async throws -> some IntentResult {
        let (directory, tagFile) = try setup(storageType: $storageType, file: $file)
        
        for tag in tags {
            directory.removeTag(withID: tag, from: tagFile)
        }
        return .result()

    }
}

//
//  GraffitiTagFile.swift
//  GraffitiTagFile
//
//  Created by Thomas Povinelli on 1/23/23.
//

import AppIntents
import os

struct GraffitiAddTagsToFile: AppIntent {
    static var title: LocalizedStringResource = "Add tags to a File"
    
    static var description: IntentDescription = IntentDescription("Add a tag to the given file by adding it to the specified tag store")
    
    @Parameter(title: "File")
    var file: IntentFile
    
    @Parameter(title: "Tags")
    var tags: [String]
    
    @Parameter(title: "Storage Type", optionsProvider: StoreFormatOptionsProvider())
    var storageType: String
    
    func perform()  throws -> some IntentResult {
        let (directory, tagFile) = try  setup(storageType: $storageType, file: $file)
        
        for tag in tags {
            try directory.addTag(Tag.tag(withString: tag), to: tagFile)
        }
        return .result()

    }
}

//
//  GraffitiAddImageTagsToFile.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/20/23.
//

import Foundation
import AppIntents

struct GraffitiAddImageTagsToFile: AppIntent {
    static var title: LocalizedStringResource = "Add tags to a File"
    
    static var description: IntentDescription = IntentDescription("Add a tag to the given file by adding it to the specified tag store")
    
    @Parameter(title: "File")
    var file: IntentFile
    
    @Parameter(title: "Tags")
    var tags: [IntentFile]
    
    @Parameter(title: "Storage Type", optionsProvider: StoreFormatOptionsProvider())
    var storageType: String
    
    func perform()  throws -> some IntentResult {
        let (directory, tagFile) = try setup(storageType: $storageType, file: $file)
        
        for tag in tags {
            if let url = tag.fileURL {
                let t = Tag.tag(imageURL: url, imageIdentifier: UUID())
                try? t.ensureThumbnail()
                directory.addTag(t, to: tagFile)
            }
        }
        return .result()

    }
}

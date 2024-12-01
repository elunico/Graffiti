//
//  GraffitiRemoveImageTagsFromFile.swift
//  GraffitiTagFile
//
//  Created by Thomas Povinelli on 2/22/23.
//

import AppIntents

struct GraffitiRemoveImageTagsFromFile: AppIntent {
    static var title: LocalizedStringResource = "Remove tags from a File"
    
    static var description: IntentDescription = IntentDescription("Remove the specified tags from the given file in the specified tag store. If the tag does not exist on the file, no action is taken")
    
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
                directory.removeTag(withID: t.id, from: tagFile)
            }
        }
        return .result()

    }
}

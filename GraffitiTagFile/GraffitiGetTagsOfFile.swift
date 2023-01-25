//
//  GetTagsOfFile.swift
//  GraffitiTagFile
//
//  Created by Thomas Povinelli on 1/24/23.
//

import Foundation
import AppIntents

struct GraffitiGetTagsOfFile: AppIntent {
    static var title: LocalizedStringResource = "Get tags of File"
    
    static var description: IntentDescription = IntentDescription("Retrieve the tags of a file as a list of strings")
    
    @Parameter(title: "File")
    var file: IntentFile
    
    @Parameter(title: "Storage Type", optionsProvider: StoreFormatOptionsProvider())
    var storageType: String
    
    func perform() async throws -> some IntentResult {
        let (_, tagFile, _) = try setup(storageType: $storageType, file: $file)

        return .result(value: tagFile.tags.map { $0.value })
    }
}

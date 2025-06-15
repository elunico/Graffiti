//
//  GetTagsOfFile.swift
//  GraffitiTagFile
//
//  Created by Thomas Povinelli on 1/24/23.
//

import Foundation
import AppIntents

struct GraffitiGetTagsOfFile: AppIntent {
    static let title: LocalizedStringResource = "Get tags of File"
    
    static let description: IntentDescription = IntentDescription("Retrieve the tags of a file as a list of strings")
    
    @Parameter(title: "File")
    var file: IntentFile
    
    @Parameter(title: "Storage Type", optionsProvider: StoreFormatOptionsProvider())
    var storageType: String
    
    func perform()  throws -> some IntentResult {
        let (_, tagFile) = try  setup(storageType: $storageType, file: $file)

        return .result(value: tagFile.tags.map { $0.value })
    }
}

//
//  GraffitiApp.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 12/31/22.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    var compressedCustomTagStore: UTType { UTType(exportedAs: "com.tom.ccts") }
}


@main
struct GraffitiApp: App {
    
    @StateObject var taggedDirectory: TaggedDirectory = TaggedDirectory.empty.copy() as! TaggedDirectory
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(taggedDirectory)
        }
        .commands(content: {
            
            CommandMenu("Tag", content: {
                Button("Edit Tags") {
                    
                }
            })
        })
    }
}

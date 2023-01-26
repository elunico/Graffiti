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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands(content: {
            
            CommandMenu("Tag", content: {
                Button("Edit Tags") {
                    
                }
            })
        })
    }
}

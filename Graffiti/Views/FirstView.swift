//
//  FirstView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 11/29/24.
//

import SwiftUI

struct FirstView: View {
    
    @State var filePath: URL? = nil
    @State var backend: TagBackend = FileTagBackend()
    
    var body: some View {
        VStack {
            GeometryReader { reader in
                
                HStack {
                    Button(action: {
                        try? getSandboxedAccess(to: FileManager.default.homeDirectoryForCurrentUser.absolutePath, thenPerform: { path in
                            let p = NSSavePanel()
                            p.directoryURL = URL(fileURLWithPath: path)
                            p.canCreateDirectories = true
                            p.nameFieldStringValue = "tagstore.ccts"
                            let resp = p.runModal()
                            if (resp == .abort || resp == .stop) {
                                return
                            } else {
                                let root = p.directoryURL?.absolutePath ?? FileManager.default.homeDirectoryForCurrentUser.absolutePath
                                filePath = URL(fileURLWithPath: root).appending(path: p.nameFieldStringValue)
                            }
                        })
                    }, label: {
                        Label("Create a new repository", systemImage: "document.badge.plus")
                    })
                    Button(action: {
                        
                    }, label: {
                        Label("Open an existing repository", systemImage: "tray")
                    })
                    Text("Working File: \(filePath?.absolutePath ?? "<none>")")

                }.padding().frame(alignment: .center)
                divider(oriented: .horizontally, measure: reader.size.width)
            }
        }.onAppear {
//            backend = FileTagBackend(withFileName: filePath, forFilesIn: directory, writer: CompressedCustomTagStoreWriter())
        }
    }
}

#Preview {
    FirstView()
}

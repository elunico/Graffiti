//
//  MainView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/4/23.
//

import Foundation
import SwiftUI

struct MainView: View {
    @State var backend: TagBackend
    @State private var directory: URL? = nil
    @StateObject var files: TaggedDirectory = .empty
    @State private var selected: Set<TaggedFile.ID> = Set()
    @State private var query: String = ""
    
    @State private var editing: Bool = false
    @State private var isPresentingConfirm: Bool = false
        
    var showOptions: () -> ()
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Button("Choose Directory") {
                    selectFolder {
                        self.directory = $0[0]
                        self.files.load(directory: $0[0].absolutePath, backend: backend)
                    }
                }
                HStack {
                    Text("Tagging: \(directory?.absoluteString ?? "<none>")")
                    Spacer()
                    TextField("Search", text: $query)
                        .frame(minWidth: 25.0, idealWidth: geometry.size.width / 8, maxWidth: 300.0, alignment: .topTrailing)
                        .help("Enter your search term. Use & and | for boolean operations. Use !word to avoid 'word' in results ")
                    
                }
                GeometryReader { tableGeometry in
                    Table(files.filter(by: query), selection: $selected, columns: {
                        TableColumn("Path", value: \TaggedFile.filename).width(ideal: tableGeometry.size.width * 5 / 15)
                        TableColumn("Kind", value: \TaggedFile.fileKind).width(ideal: tableGeometry.size.width * 2 / 15)
                        TableColumn("Tags", value: \TaggedFile.tagString).width(ideal: tableGeometry.size.width * 5 / 15)
                        TableColumn("Count", value: \TaggedFile.tagCount).width(ideal: tableGeometry.size.width / 15)
                    })
                    
                }
                HStack {
                    Button("Change save format") {
                        showOptions()
                    }
                    Spacer()
                    Button("Edit Tags") {
                        editing = true
                    }.disabled(selected.count == 0)
                    
                    Button("Clear All Tags") {
                        isPresentingConfirm = true
                    }
                }
            }
            .onClearAll(message: "This will remove EVERY tag from EVERY file in this directory\nYou cannot undo this action", isPresented: $isPresentingConfirm, clearAction: {
                for file in files.filteredFiles {
                    file.clearTags()
                }
            })
            .sheet(isPresented: $editing,  content: {
                TagView(files: files.getFiles(withIDs: selected), done: { _ in editing = false })
            })
        }
        .onDisappear(perform: self.teardown)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification), perform: {output in self.teardown()})
        .frame(minWidth: 500.0, minHeight: 500.0, alignment: .center)
        .environmentObject(files)
        .onTapGesture(count: 2, perform: {
            for file in files.getFiles(withIDs: selected) {
                print("opening file \(file)")
                NSWorkspace.shared.openFile(file.id)
            }
        })
        .padding()
    }
    
    
    func teardown() {
        for file in files.files {
            file.commit()
        }
    }
}

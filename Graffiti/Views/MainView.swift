//
//  MainView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/4/23.
//

import Foundation
import SwiftUI

extension String {
    var lastPathComponent: String? {
        self.components(separatedBy: "/").last
    }
}

struct MainView: View {
    @State var choice: ContentView.Format
    @State var backend: TagBackend
    @State var directory: URL?
    @StateObject var files: TaggedDirectory = .empty
    @State private var selected: Set<TaggedFile.ID> = Set()
    @State private var query: String = ""
    
    @State private var editing: Bool = false
    @State private var isPresentingConfirm: Bool = false
    @State private var showingMoreInfo: Bool = false
    
    var showOptions: () -> ()
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                HStack {
                    VStack {
                        HStack {
                            Text("Tagging: \(directory?.absolutePath ?? "<none>")")
                            Button(action: {showingMoreInfo.toggle()}, label: {
                                Label(showingMoreInfo ? "Less" : "More", systemImage: "info.circle")
                            })
                            
                        }
                        if showingMoreInfo {
                            Group {
                                Text("Save format: \(choice.description)")
                                Text("Tag Store: \(files.tagStore?.lastPathComponent ?? "<per file>")")
                                Button(files.tagStore == nil ? "Open Current Folder" : "Reveal Tag Store") {
                                    NSWorkspace.shared.selectFile(files.tagStore, inFileViewerRootedAtPath: directory!.absolutePath)
                                }
                            }
                        }
                        
                    }
                    Spacer()
                    TextField("Search", text: $query)
                        .frame(minWidth: 25.0, idealWidth: geometry.size.width / 8, maxWidth: 300.0, alignment: .topTrailing)
                        .help("Enter your search term. Use & and | for boolean operations. Use !word to avoid 'word' in results ")
                }
                GeometryReader { tableGeometry in
                    Table(of: TaggedFile.self, selection: $selected, columns: {
                        TableColumn("File") { item in
                            Text(item.filename)
                        }.width(ideal: tableGeometry.size.width * 5 / 15)
                        TableColumn("Kind") { item in
                            Text(item.fileKind)
                        }.width(ideal: tableGeometry.size.width * 2 / 15)
                        TableColumn("Tags") { item in
                            Text(item.tagString)
                        }.width(ideal: tableGeometry.size.width * 5 / 15)
                        TableColumn("Count") { item in
                            Text(item.tagCount)
                        }.width(ideal: tableGeometry.size.width / 15)
                    }, rows: {
                        ForEach(files.filter(by: query)) { item in
                            if selected.count <= 1 {
                                TableRow(item)
                                    .contextMenu {
                                        Button(action:  {
                                            guard let path = directory?.absolutePath else { return }
                                            
                                            if !NSWorkspace.shared.selectFile(item.id, inFileViewerRootedAtPath: path) {
                                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                                            }
                                        }, label: { Label("Reveal \(item.filename) in Finder", systemImage: "magnifyingglass") })
                                        Button(action:  {
                                            NSWorkspace.shared.openFile(item.id)
                                        }, label: { Label("Open \(item.filename)", systemImage: "arrow.forward.circle") })
                                        Button(action:  {
                                            item.clearTags()
                                        }, label: { Label("Clear All Tags for \(item.filename)", systemImage: "xmark.circle") })
                                    }
                            } else {
                                TableRow(item)
                                    .contextMenu {
                                        Button(action:  {
                                            guard let path = directory?.absolutePath else { return }
                                            
                                            if !NSWorkspace.shared.selectFile(item.id, inFileViewerRootedAtPath: path) {
                                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                                            }
                                        }, label: { Label("Reveal \(item.filename) in Finder", systemImage: "magnifyingglass") })
                                        Button(action:  {
                                            NSWorkspace.shared.openFile(item.id)
                                        }, label: { Label("Open \(item.filename)", systemImage: "arrow.forward.circle") })
                                        Button(action:  {
                                            item.clearTags()
                                        }, label: { Label("Clear All Tags for \(item.filename)", systemImage: "xmark.circle") })
                                    }
                            }
                        }
                    })
                }
                HStack {
                    Button("Change save format") {
                        self.teardown()
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
            .onClearAll(message: "This will remove EVERY tag from EVERY file currently visible in the table\nYou cannot undo this action", isPresented: $isPresentingConfirm, clearAction: {
                for file in files.filteredFiles {
                    file.clearTags()
                }
            })
            .sheet(isPresented: $editing,  content: {
                TagView(files: files.getFiles(withIDs: selected), prohibitedCharacters: backend.prohibitedCharacters, done: { _ in editing = false })
            })
        }
        .onDisappear(perform: self.teardown)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification), perform: {output in self.teardown()})
        .frame(minWidth: 500.0, minHeight: 500.0, alignment: .center)
        .environmentObject(files)
        .padding()
        .onAppear {
            guard let path = self.directory?.absolutePath else { return }
            self.files.load(directory: path, backend: backend)
        }
    }
    
    
    func teardown() {
        for file in files.files {
            file.commit()
        }
        self.files.files.removeAll(keepingCapacity: true)
        self.files.clearFilter()
        
    }
}

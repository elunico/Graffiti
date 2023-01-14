//
//  MainView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/4/23.
//

import Foundation
import SwiftUI
import QuickLook

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
    
    @State private var selectedFileURLs: [URL] = []
    @State private var selectedFileURL: URL? = nil
    
    var showOptions: () -> ()
    
    enum Orientation {
        case horizontally, vertically
    }
    
    func divider(forLayoutOrientation orientation: Orientation, measure: CGFloat) -> some View {
        if (orientation == .horizontally) {
            return Divider().frame(height: measure)
        } else {
            return Divider().frame(width: measure)
        }
    }
    
    func contextMenuOptions(orientation: Orientation) -> some View {
        Group {
            Button(action:  {
                guard let path = directory?.absolutePath else { return }
                
                if !NSWorkspace.shared.selectFile(files.getFile(withID: selected.first!)!.id, inFileViewerRootedAtPath: path) {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                }
            }, label: { Label("Reveal Item in Finder", systemImage: "folder.badge.questionmark") })
            .disabled(selected.count != 1)
            Button(action:  {
                NSWorkspace.shared.openFile(files.getFile(withID: selected.first!)!.id)
            }, label: { Label("Open Item", systemImage: "doc.viewfinder") })
            .disabled(selected.count == 0)
            divider(forLayoutOrientation: orientation, measure: 25.0)
            Button(action:  {
                files.getFile(withID: selected.first!)!.clearTags()
            }, label: { Label("Clear All Tags for Item", systemImage: "clear") })
            .disabled(selected.count == 0)
            divider(forLayoutOrientation: orientation, measure: 25.0)
            Button {
                
                guard selected.count > 0 else { return }
                self.selectedFileURLs = files.getFiles(withIDs: selected).map { URL(fileURLWithPath: $0.id) }
                self.selectedFileURL = URL(fileURLWithPath: files.getFile(withID: selected.first!)!.id)
            } label: {
                Label("QuickLook", systemImage: "eye")
            }.disabled(selected.count == 0)
        }
    }
    
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
                                
                                    .onDrag({
                                        do {
                                            guard let ts = files.tagStore else { return NSItemProvider() }
                                            let url = URL(fileURLWithPath: ts)
                                            let temporaryDirectoryURL =
                                            try FileManager.default.url(for: .itemReplacementDirectory,
                                                                        in: .userDomainMask,
                                                                        appropriateFor: url,
                                                                        create: true)
                                            
                                            
                                            let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent(ts.lastPathComponent!)
                                            
                                            guard let data = try? Data(contentsOf: url) else { return  NSItemProvider()}
                                            guard let _ = try? data.write(to: temporaryFileURL, options: .atomic) else { return  NSItemProvider()}
                                            return NSItemProvider(item: temporaryFileURL as NSSecureCoding, typeIdentifier: "public.file-url")
                                        } catch {
                                            return NSItemProvider()
                                        }
                                    }, preview: {
                                        Image(systemName: "doc")
                                        Text("\(files.tagStore!)")
                                    })
                                Button(files.tagStore == nil ? "Open Current Folder" : "Reveal Tag Store") {
                                    NSWorkspace.shared.selectFile(files.tagStore, inFileViewerRootedAtPath: directory!.absolutePath)
                                }
                            }
                        }
                        
                    }
                    
                    Spacer()
                    
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
                            TableRow(item)
                                .contextMenu {
                                    contextMenuOptions(orientation: .vertically)
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
        .toolbar(content: {
            HStack {
                contextMenuOptions(orientation: .horizontally)
            }
            TextField("Search", text: $query)
                .frame(minWidth: 200.0, maxWidth: 500.0, alignment: .topTrailing)
                .help("Enter your search term. Use & and | for boolean operations. Use !word to avoid 'word' in results ")
        })
        .quickLookPreview($selectedFileURL, in: selectedFileURLs)
        .onDisappear(perform: self.teardown)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification), perform: {output in self.teardown()})
        .frame(minWidth: 500.0, minHeight: 500.0, alignment: .center)
        .environmentObject(files)
        .padding()
        .navigationTitle("\(directory!.prettyPrinted) – Graffiti")
        .navigationDocument(directory!)
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

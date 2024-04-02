//
//  MainView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/4/23.
//

import Foundation
import SwiftUI
import QuickLook



struct MainView: View {
    static let kUserDefaultsRichKindKey = "com.tom.graffiti-richKind"
    
    @State var choice: Format
    @State var directory: URL?
    @EnvironmentObject var files: TaggedDirectory
    @EnvironmentObject var appState: ApplicationState
    @State private var selected: Set<TaggedFile.ID> = Set()
    @State private var query: String = ""
    
    @State private var selectedFileURLs: [URL] = []
    @State private var selectedFileURL: URL? = nil
    @State private var sorter: [Sorter] = []
    @State private var showOnlyUntagged: TaggedDirectory.TaggedState = .all
    
    @State private var currentFileList: [TaggedFile] = []
    
    
    var name: String {
        let affectedFiles = files.getFiles(withIDs: selected)
        let name = affectedFiles.count == 1 ? affectedFiles.first!.filename : "\(affectedFiles.count) files"
        return name
    }
    
    var tagFileTable: some View {
        GeometryReader { tableGeometry in
            VStack {
                Table(of: TaggedFile.self, selection: $selected, sortOrder: $sorter, columns: {
                    TableColumn("File", sortUsing: Sorter(keypath: \TaggedFile.filename)) { item in
                        Text(item.filename)
                    }.width(ideal: tableGeometry.size.width * 5 / 15)
                    TableColumn(appState.showSpotlightKinds  ? "Kind" : "Extension") { item in
                        if appState.showSpotlightKinds  {
                            Text(getMDKind(ofFileAtPath: item.id) ?? "<unknown>")
                        } else {
                            Text("\(URL(fileURLWithPath: item.id).pathExtension)")
                        }
                    }.width(ideal: tableGeometry.size.width * 2 / 15)
                    TableColumn("Tags") { item in
                        Text(item.tagString)
                    }.width(ideal: tableGeometry.size.width * 5 / 15)
                    TableColumn("Count") { item in
                        Text(item.tagCount)
                    }.width(ideal: tableGeometry.size.width / 15)
                    
                }, rows: {
                    ForEach(currentFileList) { item in
                        TableRow(item)
                            .contextMenu {
                                Group {
                                    Button(action: { [unowned appState] in
                                        if !selected.contains(item.id) {
                                            selected = Set([item.id])
                                        }
                                        appState.editing = true
                                        appState.currentState = .EditingTags
                                    }, label: {
                                        Label("Edit Tags of \((selected.contains(item.id) && selected.count > 1) ? "\(selected.count) items" : item.filename)", systemImage: "pencil")
                                    })
                                    
                                    Button(action:  {
                                        guard let path = directory?.absolutePath else { return }
                                        selected = Set([item.id])
                                        
                                        if !NSWorkspace.shared.selectFile(item.id, inFileViewerRootedAtPath: path) {
                                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                                        }
                                    }, label: { Label("Reveal \(item.filename) in Finder", systemImage: "folder.badge.questionmark") })
                                    
                                    Button(action:  {
                                        NSWorkspace.shared.open(item.absoluteURL)
                                        
                                    }, label: { Label("Open \((selected.contains(item.id) && selected.count > 1) ? "\(selected.count) items" : item.filename)" , systemImage: "doc.viewfinder") })
                                    
                                    divider(oriented: .horizontally, measure: 25.0)
                                    
                                    Button(action:  { [unowned appState] in
                                        if !selected.contains(item.id) {
                                            selected = Set([item.id])
                                        }
                                        appState.isPresentingConfirm = true
                                        appState.currentState = .ShowingConfirm
                                    }, label: { Label("Clear All Tags for \((selected.contains(item.id) && selected.count > 1) ? "\(selected.count) items" : item.filename)", systemImage: "clear") })
                                    
                                    divider(oriented: .horizontally, measure: 25.0)
                                    
                                    Button {
                                        guard selected.count > 0 else { return }
                                        self.selectedFileURLs = [ URL(fileURLWithPath: item.id) ]
                                        self.selectedFileURL = URL(fileURLWithPath: item.id)
                                    } label: {
                                        Label("QuickLook", systemImage: "eye")
                                    }
                                }
                            }
                    }
                }).onChange(of: sorter, perform: {
//                    if let sorter = sorter.last {
                        currentFileList.sort(using: $0)
//                    }
                    display(message: "sizeof sorter is \(sorter.count)")
                }).onChange(of: selected, perform: { _ in
                    if selected.count > 0 {
                        appState.currentState = .MainView(hasSelection: true)
                    }
                    appState.select(only: selected)
                }).onAppear {
                    _ = launch(after: .minutes(5) + .seconds(30), repeats: true) { action in
                        display(message: "Timer activated", log: .default, type: .error)
                        mdCache.removeAllObjects()
                    }
                    
                }
                
            }
        }
        
    }
    
    func MoreInfo() -> some View {
        HStack {
            VStack {
                Text("Save format: \(choice.description)")
                if files.tagStore != nil {
                    Label("Tag Store: \(files.tagStore?.lastPathComponent ?? "<per file>")", systemImage: "doc")
                    
                        .onDrag({
                            do {
                                guard let ts = files.tagStore else { return NSItemProvider() }
                                let url = URL(fileURLWithPath: ts)
                                let temporaryDirectoryURL =
                                try FileManager.default.url(for: .itemReplacementDirectory,
                                                            in: .userDomainMask,
                                                            appropriateFor: url,
                                                            create: true)
                                
                                let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent(ts.lastPathComponent)
                                
                                let data = try TPData(contentsOf: url)
                                let _ = try data.write(to: temporaryFileURL, options: .atomic)
                                return NSItemProvider(item: temporaryFileURL as NSSecureCoding, typeIdentifier: "public.file-url")
                            } catch {
                                return NSItemProvider()
                            }
                        }, preview: {
                            if files.tagStore == nil {
                                Image(systemName: "nosign")
                            } else {
                                Label("\(files.tagStore!.lastPathComponent)", systemImage: "doc")
                            }
                        })
                }
                Button(files.tagStore == nil ? "Open Current Folder" : "Reveal Tag Store") {
                    NSWorkspace.shared.selectFile(files.tagStore, inFileViewerRootedAtPath: directory!.absolutePath)
                }
            }
            Spacer()
        }
    }
    
    func MainToolbar() -> some View {
        Group {
            HStack {
                Group {
                    HStack {
                        Button(action: { [unowned files] in
                            files.undo()
                        }, label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }).disabled(files.transactions.isEmpty)
                            .keyboardShortcut("z", modifiers: [.command])
                            .help("Undo")
                        
                        Button(action: { [unowned files] in
                            files.redo()
                        }, label: {
                            Label("Redo", systemImage: "arrow.uturn.forward")
                        }).disabled(files.redoStack.isEmpty)
                            .keyboardShortcut("z", modifiers: [.command, .shift])
                            .help("Redo")
                    }
                    
                    divider(oriented: .horizontally, measure: 25.0)
                    
                    Button(action: { [unowned appState] in
                        appState.editing = true
                        appState.currentState = .EditingTags
                    }, label: {
                        Label("Edit Tags of \(name)", systemImage: "pencil")
                    }).disabled(selected.count == 0)
                        .buttonStyle(DefaultButtonStyle())
                        .keyboardShortcut(.return, modifiers: [])
                        .help("Edit Tags of \(name)")
                    
                    Button(action:  { [unowned files] in
                        guard let path = directory?.absolutePath else { return }
                        
                        if !NSWorkspace.shared.selectFile(files.getFile(withID: selected.first!)!.id, inFileViewerRootedAtPath: path) {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                        }
                    }, label: { Label("Reveal \(name) in Finder", systemImage: "folder.badge.questionmark") })
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(selected.count != 1)
                    .help("Reveal \(name) in Finder")
                    
                    Button(action:  { [unowned files] in
                        for item in files.getFiles(withIDs: selected) {
                            NSWorkspace.shared.open(item.absoluteURL)
                        }
                    }, label: { Label("Open \(name)" , systemImage: "doc.viewfinder") })
                    .keyboardShortcut(KeyEquivalent.downArrow, modifiers: [.command])
                    .disabled(selected.count == 0)
                    .help("Open \(name)")
                    
                    divider(oriented: .horizontally, measure: 25.0)
                    
                    Button(action:  { [unowned appState] in
                        appState.isPresentingConfirm = true
                        appState.currentState = .ShowingConfirm
                    }, label: { Label("Clear All Tags for \(name)", systemImage: "clear") })
                    .disabled(selected.count == 0)
                    .help("Clear All Tags for \(name)")
                    
                    divider(oriented: .horizontally, measure: 25.0)
                    
                    Button { [unowned files] in
                        guard selected.count > 0 else { return }
                        self.selectedFileURLs = files.getFiles(withIDs: selected).map { URL(fileURLWithPath: $0.id) }
                        self.selectedFileURL = URL(fileURLWithPath: files.getFile(withID: selected.first!)!.id)
                    } label: {
                        Label("QuickLook", systemImage: "eye")
                    }.disabled(selected.count == 0)
                        .keyboardShortcut(.space, modifiers: [])
                        .help("QuickLook")
                }
            }
            TextField("Search", text: $query)
                .onChange(of: query, perform: { [unowned files] _ in
                    
                    currentFileList = files.filter(by: query, within: showOnlyUntagged)
                    var noLongerSeen = selected
                    currentFileList.forEach { noLongerSeen.remove($0.id) }
                    selected.subtract(noLongerSeen)
                    if let sorter = sorter.first {
                        currentFileList.sort(using: sorter)
                    }
                    
                })
                .frame(minWidth: 200.0, maxWidth: 500.0, alignment: .topTrailing)
                .help("Enter your search term. Use & and | for boolean operations. Use !word to avoid 'word' in results ")
            
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                HStack {
                    VStack {
                        HStack {
                            Text("Tagging: \(directory?.absolutePath ?? "<none>")")
                            Button(action: {appState.showingMoreInfo.toggle()}, label: {
                                Text(appState.showingMoreInfo ? "Less" : "More")
                            })
                            Spacer()
                            VStack {
//                                Toggle("Spotlight File Kinds", isOn: $richKind)
//                                    .onChange(of: richKind, perform: { _ in
//                                        UserDefaults.thisAppDomain?.set(richKind, forKey: MainView.kUserDefaultsRichKindKey)
//                                    })
                                //                                Toggle("Show Only Untagged", isOn: $showOnlyUntagged)
                                //                                    .onChange(of: showOnlyUntagged, perform: { showOnly in
                                //                                        currentFileList = files.filter(by: query, onlyUntagged: showOnly)
                                //                                    })
                                Picker("Show: ", selection: $showOnlyUntagged, content: {
                                    Text("All Files").tag(TaggedDirectory.TaggedState.all)
                                    Text("Only Untagged").tag(TaggedDirectory.TaggedState.untagged)
                                    Text("Only Tagged").tag(TaggedDirectory.TaggedState.tagged)
                                }).onChange(of: showOnlyUntagged, perform: {
                                        currentFileList = files.filter(by: query, within: $0)
                                    }).frame(width: 200, alignment: .bottomTrailing)
                            }
                            
                            
                        }
                        if appState.showingMoreInfo {
                            MoreInfo()
                        }
                    }
                    Spacer()
                }
                tagFileTable
                HStack {
                    Button("Choose Different Format") { [unowned appState] in
                        self.teardown()
                        appState.currentState = .StartScreen
                        appState.showingOptions = true
                    }
                    Spacer()
                    Text("Showing \(currentFileList.count) of \(files.files.count) files")
                    Divider().frame(height: 20)
                    Text("Showing \(currentFileList.map { $0.tags.count }.reduce(0, +)) of \(files.files.map { $0.tags.count }.reduce(0, +)) tags")
                }
                
            }
            .onClearAll(message: (selected.count == 0 ? "This will remove EVERY tag from EVERY file currently in view in the table" : "This will remove EVERY tag from every SELECTED file in the table") + "\nYou cannot undo this action", isPresented: $appState.isPresentingConfirm, clearAction: { [unowned files] in
                if selected.count == 0 {
                    for file in files.filter(by: query, within: showOnlyUntagged) {
                        files.clearTags(of: file)
                    }
                    
                } else {
                    for file in files.getFiles(withIDs: selected) {
                        files.clearTags(of: file)
                    }
                }
            })
            .sheet(isPresented: $appState.editing,  content: {
                TagView(files: files.getFiles(withIDs: selected), prohibitedCharacters: files.prohibitedCharacters, done: { _ in appState.editing = false; appState.currentState = .MainView(hasSelection: selected.count > 0) })
            })
        }
        .toolbar(content: {
            MainToolbar()
        })
        .onChange(of: appState.doImageVision, perform: { recognize in
            files.doImageVision = recognize
        })
        .quickLookPreview($selectedFileURL, in: selectedFileURLs)
        .onDisappear(perform: self.teardown)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification), perform: {output in self.teardown()})
        .frame(minWidth: 500.0, minHeight: 500.0, alignment: .center)
        .padding()
        .navigationTitle("\(directory!.prettyPrinted) – \(files.files.count) files – \(files.files.map { $0.tags.count }.reduce(0, +)) - tags")
        .navigationDocument(directory!)
        .onAppear { [unowned files] in
            guard let path = self.directory?.absolutePath else { return }
            
            try! self.files.load(directory: path, filename: FileTagBackend.filePrefix, format: choice)
            files.convertTagStorage(to: appState.imageSaveFormat)
            currentFileList = files.filter(by: query, within: showOnlyUntagged)
            
            appState.createSelectionModel()
        }
    }
    
    func teardown() {
        self.files.commit()
        self.appState.releaseSelectionModel()
        try? pruneThumbnailCache(maxCount: 200)
        
    }
}

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
    @State private var selected: Set<TaggedFile.ID> = Set()
    @State private var query: String = ""
    
    @State private var editing: Bool = false
    @State private var isPresentingConfirm: Bool = false
    @State private var showingMoreInfo: Bool = false
    
    @State private var selectedFileURLs: [URL] = []
    @State private var selectedFileURL: URL? = nil
    @State private var richKind: Bool = false
    @State private var sorter: [Sorter] = []
    
    @State private var currentFileList: [TaggedFile] = []
    
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
                    
                    TableColumn(richKind  ? "Kind" : "Extension") { item in
                        if richKind  {
                            if let mditem = MDItemCreate(nil, item.id as CFString),
                               let mdnames = MDItemCopyAttributeNames(mditem),
                               let mdattrs = MDItemCopyAttributes(mditem, mdnames) as? [String:Any],
                               let mdkind = mdattrs[kMDItemKind as String] as? String {
                                Text("\(mdkind)")
                            } else {
                                Text("<unknown>")
                            }
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
                                    Button(action: {
                                        if !selected.contains(item.id) {
                                            selected = Set([item.id])
                                        }
                                        editing = true
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
//                                        NSWorkspace.shared.openFile(item.id)
                                        NSWorkspace.shared.open(item.absoluteURL)
                                        
                                    }, label: { Label("Open \((selected.contains(item.id) && selected.count > 1) ? "\(selected.count) items" : item.filename)" , systemImage: "doc.viewfinder") })
                                    
                                    divider(forLayoutOrientation: .horizontally, measure: 25.0)
                                    
                                    Button(action:  {
                                        if !selected.contains(item.id) {
                                            selected = Set([item.id])
                                        }
                                        isPresentingConfirm = true
                                    }, label: { Label("Clear All Tags for \((selected.contains(item.id) && selected.count > 1) ? "\(selected.count) items" : item.filename)", systemImage: "clear") })
                                    
                                    divider(forLayoutOrientation: .horizontally, measure: 25.0)
                                    
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
                }).onChange(of: sorter, perform: { _ in
                    if let sorter = sorter.first {
                        currentFileList.sort(using: sorter)
                    }
                })
                
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
                                
                                guard let data = try? TPData(contentsOf: url) else { return  NSItemProvider()}
                                guard let _ = try? data.write(to: temporaryFileURL, options: .atomic) else { return  NSItemProvider()}
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
                        Button(action: {
                            files.undo()
                        }, label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }).disabled(files.transactions.isEmpty)
                            .keyboardShortcut("z", modifiers: [.command])
                            .help("Undo")
                        
                        Button(action: {
                            files.redo()
                        }, label: {
                            Label("Redo", systemImage: "arrow.uturn.forward")
                        }).disabled(files.redoStack.isEmpty)
                            .keyboardShortcut("z", modifiers: [.command, .shift])
                            .help("Redo")
                    }
                    
                    divider(forLayoutOrientation: .horizontally, measure: 25.0)
                    
                    Button(action: {
                        editing = true
                    }, label: {
                        Label("Edit Tags of \(name)", systemImage: "pencil")
                    }).disabled(selected.count == 0)
                        .buttonStyle(DefaultButtonStyle())
                        .keyboardShortcut(.return, modifiers: [])
                        .help("Edit Tags of \(name)")
                    
                    Button(action:  {
                        guard let path = directory?.absolutePath else { return }
                        
                        if !NSWorkspace.shared.selectFile(files.getFile(withID: selected.first!)!.id, inFileViewerRootedAtPath: path) {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                        }
                    }, label: { Label("Reveal \(name) in Finder", systemImage: "folder.badge.questionmark") })
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(selected.count != 1)
                    .help("Reveal \(name) in Finder")
                    
                    Button(action:  {
                        for item in files.getFiles(withIDs: selected) {
                            NSWorkspace.shared.open(item.absoluteURL)
                        }
                    }, label: { Label("Open \(name)" , systemImage: "doc.viewfinder") })
                    .keyboardShortcut(KeyEquivalent.downArrow, modifiers: [.command])
                    .disabled(selected.count == 0)
                    .help("Open \(name)")
                    
                    divider(forLayoutOrientation: .horizontally, measure: 25.0)
                    
                    Button(action:  {
                        isPresentingConfirm = true
                    }, label: { Label("Clear All Tags for \(name)", systemImage: "clear") })
                    .disabled(selected.count == 0)
                    .help("Clear All Tags for \(name)")
                    
                    divider(forLayoutOrientation: .horizontally, measure: 25.0)
                    
                    Button {
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
                .onChange(of: query, perform: { _ in
                    
                    currentFileList = files.filter(by: query)
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
                            Button(action: {showingMoreInfo.toggle()}, label: {
                                Text(showingMoreInfo ? "Less" : "More")
                            })
                            Spacer()
                            Toggle("Spotlight File Kinds", isOn: $richKind)
                                .onChange(of: richKind, perform: { _ in
                                    UserDefaults.this?.set(richKind, forKey: MainView.kUserDefaultsRichKindKey)
                                })
                            
                        }
                        if showingMoreInfo {
                            MoreInfo()
                        }
                    }
                    Spacer()
                }
                tagFileTable
                HStack {
                    Spacer()
                    Text("\(files.files.count) files")
                    Divider().frame(height: 20)
                    Text("\(files.files.map { $0.tags.count }.reduce(0, +)) tags")
                }
                
            }
            .onClearAll(message: (selected.count == 0 ? "This will remove EVERY tag from EVERY file currently in view in the table" : "This will remove EVERY tag from every SELECTED file in the table") + "\nYou cannot undo this action", isPresented: $isPresentingConfirm, clearAction: {
                if selected.count == 0 {
                    for file in files.filter(by: query) {
                        file.clearTags()
                    }
                } else {
                    for file in files.getFiles(withIDs: selected) {
                        file.clearTags()
                    }
                }
            })
            .sheet(isPresented: $editing,  content: {
                TagView(files: files.getFiles(withIDs: selected), prohibitedCharacters: files.prohibitedCharacters, done: { _ in editing = false })
            })
        }
        .toolbar(content: {
            MainToolbar()
        })
        .quickLookPreview($selectedFileURL, in: selectedFileURLs)
        .onDisappear(perform: self.teardown)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification), perform: {output in self.teardown()})
        .frame(minWidth: 500.0, minHeight: 500.0, alignment: .center)
        .padding()
        .navigationTitle("\(directory!.prettyPrinted) – \(files.files.count) files – \(files.files.map { $0.tags.count }.reduce(0, +)) - tags")
        .navigationDocument(directory!)
        .onAppear {
            guard let path = self.directory?.absolutePath else { return }
            DispatchQueue.main.async {
                try! self.files.load(directory: path, format: choice)
                currentFileList = files.filter(by: query)
            }
            richKind = UserDefaults.this?.bool(forKey: MainView.kUserDefaultsRichKindKey) ?? false
        }
    }
    
    func teardown() {
        self.files.commit()
        self.files.files.removeAll(keepingCapacity: true)
    }
}

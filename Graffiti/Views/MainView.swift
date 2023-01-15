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

class Sorter: SortComparator {
    typealias Compared = TaggedFile
    
    static func == (lhs: Sorter, rhs: Sorter) -> Bool {
        lhs.order == rhs.order
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(order)
    }
    
    var order: SortOrder = .forward
    
    func compare(_ lhs: TaggedFile, _ rhs: TaggedFile) -> ComparisonResult {
        lhs.filename.compare(rhs.filename)
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
    @State private var richKind: Bool = false
    @State private var sorter: [Sorter] = []
    
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
                            
                        }
                        if showingMoreInfo {
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
                                                    
                                                    
                                                    let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent(ts.lastPathComponent!)
                                                    
                                                    guard let data = try? Data(contentsOf: url) else { return  NSItemProvider()}
                                                    guard let _ = try? data.write(to: temporaryFileURL, options: .atomic) else { return  NSItemProvider()}
                                                    return NSItemProvider(item: temporaryFileURL as NSSecureCoding, typeIdentifier: "public.file-url")
                                                } catch {
                                                    return NSItemProvider()
                                                }
                                            }, preview: {
                                                if files.tagStore == nil {
                                                    Image(systemName: "nosign")
                                                } else {
                                                    Label("\(files.tagStore!.lastPathComponent!)", systemImage: "doc")
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
                        
                    }
                    
                    Spacer()
                    
                }
                GeometryReader { tableGeometry in
                    Table(of: TaggedFile.self, selection: $selected, sortOrder: $sorter, columns: {
                        TableColumn("File", sortUsing: Sorter()) { item in
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
//                            Text((try? URL(fileURLWithPath: item.id).resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier) ?? "<unknown>")
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
                                    Group {
                                        Button(action: {
                                            if !selected.contains(item.id) {
                                                selected = Set([item.id])
                                            }
                                            editing = true
                                        }, label: {
                                            Label("Edit Tags of \(selected.contains(item.id) ? "\(selected.count) items" : item.filename)", systemImage: "pencil")
                                        })

                                                                                    
                                        Button(action:  {
                                            guard let path = directory?.absolutePath else { return }
                                            
                                            if !NSWorkspace.shared.selectFile(item.id, inFileViewerRootedAtPath: path) {
                                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                                            }
                                        }, label: { Label("Reveal \(item.filename) in Finder", systemImage: "folder.badge.questionmark") })
                                        .disabled(selected.count != 1)

                                        
                                        Button(action:  {
                                            NSWorkspace.shared.openFile(item.id)
                                            
                                        }, label: { Label("Open \(selected.contains(item.id) ? "\(selected.count) items" : item.filename)" , systemImage: "doc.viewfinder") })
                                        

                                        
                                        divider(forLayoutOrientation: .horizontally, measure: 25.0)
                                        
                                        Button(action:  {
                                            if !selected.contains(item.id) {
                                                selected = Set([item.id])
                                            }
                                            isPresentingConfirm = true
                                        }, label: { Label("Clear All Tags for \(selected.contains(item.id) ? "\(selected.count) items" : item.filename)", systemImage: "clear") })
                                        
                                        
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
                    })
                    
                }
            }
            .onClearAll(message: (selected.count == 0 ? "This will remove EVERY tag from EVERY file currently in view in the table" : "This will remove EVERY tag from every SELECTED file in the table") + "\nYou cannot undo this action", isPresented: $isPresentingConfirm, clearAction: {
                if selected.count == 0 {
                    for file in files.filteredFiles {
                        file.clearTags()
                    }
                } else {
                    for file in files.getFiles(withIDs: selected) {
                        file.clearTags()
                    }
                }
            })
            
            .sheet(isPresented: $editing,  content: {
                TagView(files: files.getFiles(withIDs: selected), prohibitedCharacters: backend.prohibitedCharacters, done: { _ in editing = false })
            })
        }
        .toolbar(content: {
            HStack {
                Group {
                    Button(action: {
                        editing = true
                    }, label: {
                        Label("Edit Tags of \(name)", systemImage: "pencil")
                    }).disabled(selected.count == 0)
                        .buttonStyle(DefaultButtonStyle())
                        .keyboardShortcut(.return, modifiers: [])
                    
                    Button(action:  {
                        guard let path = directory?.absolutePath else { return }
                        
                        if !NSWorkspace.shared.selectFile(files.getFile(withID: selected.first!)!.id, inFileViewerRootedAtPath: path) {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                        }
                    }, label: { Label("Reveal \(name) in Finder", systemImage: "folder.badge.questionmark") })
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(selected.count != 1)
                    
                    Button(action:  {
                        for item in files.getFiles(withIDs: selected) {
                            NSWorkspace.shared.openFile(item.id)
                        }
                    }, label: { Label("Open \(name)" , systemImage: "doc.viewfinder") })
                    .keyboardShortcut(KeyEquivalent.downArrow, modifiers: [.command])
                    .disabled(selected.count == 0)
                    
                    divider(forLayoutOrientation: .horizontally, measure: 25.0)
                    
                    Button(action:  {
                        isPresentingConfirm = true
                    }, label: { Label("Clear All Tags for \(name)", systemImage: "clear") })
                    .disabled(selected.count == 0)
                    
                    divider(forLayoutOrientation: .horizontally, measure: 25.0)
                    
                    Button {
                        guard selected.count > 0 else { return }
                        self.selectedFileURLs = files.getFiles(withIDs: selected).map { URL(fileURLWithPath: $0.id) }
                        self.selectedFileURL = URL(fileURLWithPath: files.getFile(withID: selected.first!)!.id)
                    } label: {
                        Label("QuickLook", systemImage: "eye")
                    }.disabled(selected.count == 0)
                        .keyboardShortcut(.upArrow, modifiers: [.command])
                }
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

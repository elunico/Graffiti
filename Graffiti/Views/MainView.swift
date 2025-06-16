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
    @State private var oselected: Set<Tag.ID> = Set()
    
    // Search items
    @State private var query: String = ""
    @State private var searchFileTokens: [SearchFilesToken] = []
    @State private var recSFT: [SearchFilesToken] = [.Tagged, .Untagged]
    @State private var showSearch: Bool = false

    
    @State private var selectedFileURLs: [URL] = []
    @State private var selectedFileURL: URL? = nil
    @State private var sorter: [Sorter] = []
    @State private var showOnlyUntagged: TaggedDirectory.TaggedState = .all
    
    @State private var currentFileList: [TaggedFile] = []
    
    @State private var didUndoCount: Int = 0
    @State private var didRedoCount: Int = 0
    
    @State private var mainTab: Int = 1
    
//    @State var doUpdate: Bool = false
    
    enum SelectionIdentifier: String {
        case files = "main-view#files"
        case tags = "main-view#tags"
    }
    
    var name: String {
        let affectedFiles = files.getFiles(withIDs: selected)
        let name = affectedFiles.count == 1 ? affectedFiles.first!.filename : "\(affectedFiles.count) files"
        return name
    }
    
    var currentTagList: [Tag] {
        files.files.flatMap(\.tags).unique()
    }
    
    var tagListTable: some View {
        TagView(files: [], query: $query, tokens: $searchFileTokens,  allowAdding: false, universalView: true, prohibitedCharacters: files.prohibitedCharacters, done: { _ in })
            .environmentObject(files)
        
    }
    
    var oldtagListTable: some View {
        Table(of: Tag.self, selection: $oselected, columns: {
            TableColumn("ID") { item in
                Text(item.id.uuidString)
            }
            TableColumn("Value?") { item in
                Text(item.value)
            }
            TableColumn("Image URL") { (item: Tag) in
                Text(item.image?.absolutePath ?? "<none>")
            }
            TableColumn("Image Storage Format") { item in
                Text((item.imageFormat == .content ? "Entire Image" : "Image Reference"))
            }
        }, rows: {
            ForEach(currentTagList, id: \.self) { item in
                TableRow(item)
                    .contextMenu(menuItems: {
                        Button("Edit") {
                            appState.isEditingTag = true
                            appState.editTargetTag = item
                        }
                    })
                //                    .onTapGesture(count: 2, perform: {
                //                        isEditingTag = true
                //                        editTargetTag = item
                //                    })
            }
        }).onAppear{
            appState.createSelectionModel(for: MainView.SelectionIdentifier.tags.rawValue)
        }
        .onDisappear {
            oselected.removeAll()
            appState.releaseSelectionModel()
        }
    }
    
    var tagFileTableMainTable: some View {
        Table(of: TaggedFile.self, selection: $selected, sortOrder: $sorter, columns: {
            TableColumn("File", sortUsing: Sorter(keypath: \TaggedFile.filename)) { item in
                Text(item.filename)
            }//.width(ideal: tableGeometry.size.width * 5 / 15)
            TableColumn(appState.showSpotlightKinds  ? "Kind" : "Extension") { item in
                if appState.showSpotlightKinds  {
                    Text(getMDKind(ofFileAtPath: item.id) ?? "<unknown>")
                } else {
                    Text("\(URL(fileURLWithPath: item.id).pathExtension)")
                }
            }//.width(ideal: tableGeometry.size.width * 2 / 15)
            TableColumn("Tags") { item in
                Text(item.tagString)
            }//.width(ideal: tableGeometry.size.width * 5 / 15)
            TableColumn("Count") { item in
                Text(item.tagCount)
            }//.width(ideal: tableGeometry.size.width / 15)
            
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
                                Label("Edit Tags of \((selected.contains(item.id) && selected.count > 1) ? "\(selected.count) items" : item.filename)", systemImage: "custom.tag.badge.plus")
                            })
                            
                            Button(action:  {
                                guard let path = directory?.absolutePath else { return }
                                selected = Set([item.id])
                                
                                if !NSWorkspace.shared.selectFile(item.id, inFileViewerRootedAtPath: path) {
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                                }
                            }, label: { Label("Reveal \(item.filename) in Finder", systemImage: "document.viewfinder") })
                            
                            Button(action:  {
                                NSWorkspace.shared.open(item.absoluteURL)
                                
                            }, label: { Label("Open \((selected.contains(item.id) && selected.count > 1) ? "\(selected.count) items" : item.filename)" , systemImage: "macwindow.and.cursorarrow") })
                            
                            divider(oriented: .horizontally, measure: 25.0)
                            
                            Button(action:  { [unowned appState] in
                                if !selected.contains(item.id) {
                                    selected = Set([item.id])
                                }
                                appState.isPresentingConfirm = true
                                appState.currentState = .ShowingConfirm
                            }, label: { Label("Clear All Tags for \((selected.contains(item.id) && selected.count > 1) ? "\(selected.count) items" : item.filename)", systemImage: "custom.tag.badge.xmark").foregroundStyle(.red) })
                            
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
            
        })
    }
    
    
    var tagFileTable: some View {
        GeometryReader { tableGeometry in
            VStack {
                tagFileTableMainTable
            }.onChange(of: sorter, perform: {
                //                    if let sorter = sorter.last {
                currentFileList.sort(using: $0)
                //                    }
            }).onChange(of: mainTab, perform: { _ in
                //                    files.doUpdate.toggle()
                
            }).onChange(of: selected, perform: { _ in
                if selected.count > 0 {
                    appState.currentState = .MainView(hasSelection: true)
                }
                appState.select(only: selected)
            }).onAppear {
                _ = launch(after: .minutes(5) + .seconds(30), repeats: true) { action in
                    reportWarning("Timer activated")
                    //                        mdCache.removeAllObjects()
                }
                appState.createSelectionModel(for: MainView.SelectionIdentifier.files.rawValue)
                
            }.onDisappear(perform: {
                selected.removeAll()
                appState.releaseSelectionModel()
            })
            
        }
    }
    
    
    
    func MoreInfo() -> some View {
        HStack {
            VStack {
                Text("Save format: \(choice.description)")
                if files.tagStore != nil {
                    Label("Tag Store: \(files.tagStore?.lastPathComponent ?? "<per file>")", systemImage: "doc").foregroundColor(.accentColor)
                    
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
                                Label("\(files.tagStore!.lastPathComponent)", systemImage: "doc").foregroundColor(.accentColor)
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
    
    @available(macOS 14, *)
    func undoButton() -> some View {
        fallbackUndoButton()
            .symbolEffect(.bounce, value: didUndoCount)
    }
    
    func fallbackUndoButton() -> some View {
        Button(action: { [unowned files] in
            files.undo()
            didUndoCount += 1
        }, label: {
            Label("Undo", systemImage: "arrow.uturn.backward")
        }).disabled(files.transactions.isEmpty)
            .keyboardShortcut("z", modifiers: [.command])
            .help("Undo")
    }
    
    @available(macOS 14, *)
    func redoButton() -> some View {
        fallbackRedoButton()
            .symbolEffect(.bounce, value: didRedoCount)
        
    }
    
    func fallbackRedoButton() -> some View {
        Button(action: { [unowned files] in
            files.redo()
            didRedoCount += 1
        }, label: {
            Label("Redo", systemImage: "arrow.uturn.forward")
        }).disabled(files.redoStack.isEmpty)
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .help("Redo")
    }
    
    func performSearch() {
        currentFileList = files.filter(by: query, and: searchFileTokens, within: showOnlyUntagged)
        var noLongerSeen = selected
        currentFileList.forEach { noLongerSeen.remove($0.id) }
        selected.subtract(noLongerSeen)
        if let sorter = sorter.first {
            currentFileList.sort(using: sorter)
        }
    }

    
    var topBarWithInfo: some View {
        VStack {
            HStack {
                Text("Tagging: \(directory?.absolutePath ?? "<none>")")
                Button(action: {appState.showingMoreInfo.toggle()}, label: {
                    if #available(macOS 14.0, *) {
                        Label(appState.showingMoreInfo ? "Less" : "More", systemImage: appState.showingMoreInfo ? "arrowshape.up":"arrowshape.down")
                            .contentTransition(.symbolEffect(.replace))
                    } else {
                        Label(appState.showingMoreInfo ? "Less" : "More", systemImage: appState.showingMoreInfo ? "arrowshape.up":"arrowshape.down")
                    }
                })
                Spacer()
                // TODO: Search with tokens allows the user to filter for tagged or not already, is this picker needed?
//                if mainTab == 1 {
//                    VStack {
//                        Picker("Show: ", selection: $showOnlyUntagged, content: {
//                            Text("All Files").tag(TaggedDirectory.TaggedState.all)
//                            Text("Only Untagged").tag(TaggedDirectory.TaggedState.untagged)
//                            Text("Only Tagged").tag(TaggedDirectory.TaggedState.tagged)
//                        }).onChange(of: showOnlyUntagged, perform: {
//                            currentFileList = files.filter(by: query, and: searchFileTokens, within: $0)
//                        }).frame(width: 200, alignment: .bottomTrailing)
//                    }
//                }
                
            }
            if appState.showingMoreInfo {
                MoreInfo()
            }
        }
    }
    
    func mainToolbar() -> some ToolbarContent {
        Group {
            if #available(macOS 14, *) {
                ToolbarItem {
                    undoButton()
                }
                
            } else {
                ToolbarItem {
                    fallbackUndoButton()
                }
            }
            
            if #available(macOS 14, *) {
                ToolbarItem {
                    redoButton()
                }
            } else {
                ToolbarItem {
                    fallbackRedoButton()
                }
            }
            
            //            divider(oriented: .horizontally, measure: 25.0)
            //            if #available(macOS 26.0, *) {
            //                ToolbarSpacer(.fixed)
            //            } else {
            //                divider(oriented: .horizontally, measure: 25.0)
            //            }
            
            //
            ToolbarItem {
                Button(action: { [unowned appState] in
                    appState.editing = true
                    appState.currentState = .EditingTags
                }, label: {
                    Label("Edit Tags of \(name)", image: "custom.tag.badge.plus")
                    
                }).disabled(selected.count == 0)
                    .buttonStyle(DefaultButtonStyle())
                    .keyboardShortcut(.return, modifiers: [])
                    .help("Edit Tags of \(name)")
            }
            //
            //
            //
            ToolbarItem {
                Button(action:  { [unowned files] in
                    guard let path = directory?.absolutePath else { return }
                    
                    if !NSWorkspace.shared.selectFile(files.getFile(withID: selected.first!)!.id, inFileViewerRootedAtPath: path) {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    }
                }, label: { Label("Reveal \(name) in Finder", systemImage: "document.viewfinder") })
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(selected.count != 1)
                .help("Reveal \(name) in Finder")
            }
            ToolbarItem {
                Button(action:  { [unowned files] in
                    for item in files.getFiles(withIDs: selected) {
                        NSWorkspace.shared.open(item.absoluteURL)
                    }
                }, label: { Label("Open \(name)" , systemImage: "macwindow.and.cursorarrow") })
                .keyboardShortcut(KeyEquivalent.downArrow, modifiers: [.command])
                .disabled(selected.count == 0)
                .help("Open \(name)")
            }
            //
            //                divider(oriented: .horizontally, measure: 25.0)
            ToolbarItem {
                Button(action:  { [unowned appState] in
                    appState.isPresentingConfirm = true
                    appState.currentState = .ShowingConfirm
                }, label: { Label("Remove All Tags for \(name)", image: "custom.tag.badge.xmark").foregroundColor(selected.count == 0 ? .secondary : .red) })
                .disabled(selected.count == 0)
                .help("Clear All Tags for \(name)")
                //                    }
            }
            
            ToolbarItem {
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
    }
    
    var footerSection: some View {
        HStack {
            Button(action: { [unowned appState] in
                appState.currentState = .StartScreen
                appState.showingOptions = true
            }, label: {
                Label("Return to Directory Selection", systemImage: "arrow.uturn.backward")
            })
            Spacer()
            if mainTab == 1 {
                Text("Showing \(currentFileList.count) of \(files.files.count) files")
                Divider().frame(height: 20)
            }
            Text("Showing \(currentFileList.map { $0.tags.count }.reduce(0, +)) of \(files.files.map { $0.tags.count }.reduce(0, +)) tags")
            Button(action: {
                appState.isLocked = true
            },label: {
                Image(systemName: "lock")
            })
        }
    }
    
    var mainStack: some View {
        VStack {
            HStack {
                topBarWithInfo
                Spacer()
            }
            Group {
                TabView(selection: $mainTab) {
                    tagFileTable.tabItem({
                        Label("Files", systemImage: "doc")
                    }).tag(1)
                    
                    tagListTable.tabItem {
                        Label("Tags", systemImage: "tag")
                    }.tag(2)
                    
                }.onChange(of: mainTab, perform: { newVal in
                    if newVal == 1 {
                        self.recSFT = [.Tagged, .Untagged]
                    } else if newVal == 2 {
                        self.recSFT = [.Image, .String]
                    }
                })
                footerSection
            }
            
        }
    }
    
    var isEditingTagView: some View {
        VStack {
            Text("Tag \(appState.editTargetTag.id.uuidString)").font(.headline)
            VStack {
                Text("Value").font(.caption)
                if appState.editTargetTag.image == nil {
                    TextField("Value", text: $appState.editTargetTag.value)
                } else {
                    // TODO: cannot change image from the main tag view
                    ImageSelector(selectedImage: $appState.editTargetTag.image,  onClick: { url in
                        // TODO: image selector needs to be totally revamped so that I don't have to provide this, it should do all the copying adn owning and only bind to the URL
                    }, onDroppedFile: {(url, provider) in
                        return false
                    })
                }
            }.frame(alignment: .trailing)
            
            Button("Close") {
                appState.isEditingTag = false
            }
        }
    }
    
    var bodyRoot: some View {
        GeometryReader { geometry in
            mainStack
            .onClearAll(message: (selected.count == 0 ? "This will remove EVERY tag from EVERY file currently in view in the table" : "This will remove EVERY tag from every SELECTED file in the table") + "\nYou cannot undo this action", isPresented: $appState.isPresentingConfirm, clearAction: { [unowned files] in
                if selected.count == 0 {
                    for file in files.filter(by: query, and: searchFileTokens, within: showOnlyUntagged) {
                        files.clearTags(of: file)
                    }
                    
                } else {
                    for file in files.getFiles(withIDs: selected) {
                        files.clearTags(of: file)
                    }
                }
            })
            .sheet(isPresented: $appState.editing,  content: {
                TagView(files: files.getFiles(withIDs: selected), query: $query, tokens: $searchFileTokens, universalView: false, prohibitedCharacters: files.prohibitedCharacters, done: { _ in
                    appState.editing = false
                    appState.currentState = .MainView(hasSelection: selected.count > 0)
                })
            })
            .sheet(isPresented: $appState.isEditingTag, content: {
               isEditingTagView.padding()
                
            })
        }
        .toolbar {
            mainToolbar()
        }
    }
    
    var bodyRootWithSearch: some View {
        
        if #available(macOS 14.0, *) {
            AnyView(bodyRoot
                .searchable(text: $query, tokens: $searchFileTokens, isPresented: $showSearch, placement: .sidebar, prompt: "Search by name or tag", token: { token in Text(token.description) }))
        } else {
            AnyView(bodyRoot
                .searchable(text: $query, tokens: $searchFileTokens, placement: .sidebar, prompt: "Search by name or tag", token: { token in Text(token.description) }))
        }
        
        //        .help("Enter your search term. Use & and | for boolean operations. Use !word to avoid 'word' in results ")
        
    }
    
    var body: some View {
        bodyRootWithSearch
        .onChange(of: query, perform: { _ in
            performSearch()
        })
        .onChange(of: searchFileTokens, perform: { _ in
            performSearch()
        })
        .onChange(of: appState.doImageVision, perform: { recognize in
            files.imageVisionSet(doVision: recognize)
        })
        .quickLookPreview($selectedFileURL, in: selectedFileURLs)
        .onDisappear(perform: self.teardown)
        .frame(minWidth: 500.0, minHeight: 500.0, alignment: .center)
        .padding()
        .navigationTitle("\(directory!.prettyPrinted) – \(files.files.count) files – \(files.files.map { $0.tags.count }.reduce(0, +)) - tags")
        .navigationDocument(directory!)
        .onAppear { [unowned files] in
            guard let path = self.directory?.absolutePath else { return }
            try! self.files.load(directory: path, filename: FileTagBackend.filePrefix, format: choice, doTextRecognition: appState.doImageVision)
            currentFileList = files.filter(by: query, and: searchFileTokens, within: showOnlyUntagged)
            //            appState.createSelectionModel(for: MainView.selectionIdenfitier)
        }
    }
    
    
    func teardown() {
        self.files.commit()
        //        self.appState.releaseSelectionModel()
        try? pruneThumbnailCache(maxCount: 200)
    }
}

//
//  TagView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/4/23.
//

import Foundation
import SwiftUI
import os
import UniformTypeIdentifiers

enum AddTagError: Error {
    case generic
}

struct RetainedImage {
    var id: UUID?
    var url: URL?
    var retainedURL: URL?
    var type: UTType {
        getTypeOfImage(url: url!)
    }
    
    var isPresent: Bool {
        self.url != nil && self.retainedURL != nil
    }
    
    static func getRetainedURL(originalURL: URL, withID id: UUID) throws -> URL {
        let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.applicationSupportDirectory, .userDomainMask, true).first!
        let name = originalURL.lastPathComponent
        let imageDirectory = URL(fileURLWithPath: path).appending(path: "retained-images")
        
        return try  getSandboxedAccess(to: imageDirectory.absolutePath, thenPerform: { imageDirectoryString in
            let imageDirectory = URL(fileURLWithPath: imageDirectoryString)
            try ensureExistance(ofDirectory: imageDirectory)
            var ownedURL = imageDirectory.appending(path: name)
            ownedURL = try copyWithReplacement(at: originalURL, to: ownedURL)
            return ownedURL
        })
    }
    
    init() {
    }
    
    init(url: URL, withID id: UUID) throws {
        self.url = url
        self.id = id
        self.retainedURL = try RetainedImage.getRetainedURL(originalURL: url, withID: id)
        try copyWithReplacement(at: url, to: retainedURL!)
    }
    
    func persist() throws -> URL  {
        if (!isPresent) { fatalError("Do not call persist if !isPresent") }
        let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.applicationSupportDirectory, .userDomainMask, true).first!
        
        let imageDirectory = URL(fileURLWithPath: path).appending(path: "owned-images")
        
        return try  getSandboxedAccess(to: imageDirectory.absolutePath, thenPerform: { imageDirectoryString in
            let imageDirectory = URL(fileURLWithPath: imageDirectoryString)
            try ensureExistance(ofDirectory: imageDirectory)
            
            var ownedURL = imageDirectory.appending(path: id!.uuidString).appendingPathExtension(for: type)
            ownedURL = try copyWithReplacement(at: retainedURL!, to: ownedURL)
            return ownedURL
        })
    }
    
    mutating func destroy() throws {
        try FileManager.default.removeItem(at: retainedURL!)
        self.url = nil
        self.id = nil
        self.retainedURL = nil
    }
}

struct TagView: View {
    @State var files: Set<TaggedFile>
    @State var selected: Set<Tag.ID> = [] 
    @State var currentTag: String = ""
    @State var showingHelp = false
    @State var tagImage: RetainedImage = RetainedImage()
    @State var qlPreviewLink: URL? = nil
    @State var selectedView: ViewSelection = .text
    var query: Binding<String>
    @EnvironmentObject var directory: TaggedDirectory
    @EnvironmentObject var appState: ApplicationState
    
    @State var message: String = ""
    @State var showingError: Bool = false
    
    @State var chosenFormat: Tag.ImageFormat = .url
    @State var tags: Array<Tag> = []
    
    @State var isTargetedForDrop: Bool = false
    
    @State var stringTag: Tag? = nil
    
    @State var allowAdding: Bool = true
    @State var universalView: Bool = false 
    
//    @Binding var doUpdate: Bool 
    
    var prohibitedCharacters: Set<Character>
    var done: (Set<TaggedFile>) -> ()
    
    static var selectionIdentifier = "tag-view"
    
    enum ViewSelection: Hashable {
        case text
        case image
    }
    
    func performDelete()  {
        for index in selected {
            let tag =  Tag.tag(fromID: index)!
            let f = files.filter { $0.tags.contains(tag) }.map { $0 }
            print("\(f.count) Files have the tag")
            directory.removeTag(withID: index, fromAll: f)
        }
        tags = files.map { $0.tags }.flatten().unique()
        selected = []
    }
    
   
    
    var buttonBar: some View {
        HStack {
            HStack {
                Button("Undo") {
                    directory.undo()
                }.disabled(directory.transactions.isEmpty)
                    .keyboardShortcut("z", modifiers: [.command])
                Button("Redo") {
                    directory.redo()
                }.disabled(directory.redoStack.isEmpty)
                    .keyboardShortcut("z", modifiers: [.shift, .command])
            }
            Spacer()
            HStack {
                Button("Delete Tag") {
                    self.performDelete()
                }.disabled(selected.isEmpty)
                Button("Add Tag") {
                    self.addCurrentTag()
                }.disabled(currentTag == "" && tagImage.url == nil)
            }
        }
    }
    
    var addTextView: some View {
        HStack {
            Spacer()
            
            TextField("Add Tag", text: $currentTag, prompt: Text("Tag"))
                .onChange(of: currentTag) { _ in
                    currentTag.removeAll(where: { prohibitedCharacters.contains($0) })
                }.onSubmit {
                    self.addCurrentTag()
                }
            Spacer()
            
        }
    }
    
    var showingStringsSheet: some View {
        VStack {
            if stringTag == nil {
                Text("No selection").font(.headline)
            } else {
                Button("Copy all strings") {
                    NSPasteboard.general.prepareForNewContents()
                    NSPasteboard.general.setString(stringTag!.imageTextContent.joined(separator: "\n"), forType: .string)
                }
                List(stringTag!.imageTextContent, id: \.self) { item in
                    HStack {
                        Text(item).textSelection(.enabled)
                        Spacer()
                        Button("Copy") {
                            NSPasteboard.general.prepareForNewContents()
                            NSPasteboard.general.setString(item, forType: .string)
                        }
                    }
                    
                }
            }
            Button("Close") {
                appState.isShowingStrings = false
            }
        }.padding()
        .frame(minWidth: 600.0, minHeight: 600.0)
    }
    
    var addImageView: some View {
        Group {
            ImageSelector(selectedImage: $tagImage.retainedURL, onClick: { _ in
                DispatchQueue.main.async {
                    selectFile(ofTypes: [.image]) { urls in
                        guard let originalURL = urls.first else { return }
//                        let url = try! acquireImage(at: originalURL)
                        tagImage = try! RetainedImage(url: originalURL, withID: UUID())
                    }
                }
            }, onDroppedFile: { (_, providers) in
                return receiveDroppedImage(from: providers)
            })
         
        }
    }
    
    var isImageTagSelected: Bool {
        if selected.isEmpty {
            return false
        }
        if let id = selected.first {
            return Tag.tag(fromID: id)?.image != nil 
        } else {
            return false
        }
    }
    
    private func tagMatchesString(string: String, tag: Tag) -> Bool {
        let substr = string[string.index(after: string.startIndex)...]
        print("Checking for match", tag.debugDescription, string)
        if string.hasPrefix("!") {
            return !tag.searchableMetadataString.contains(substr)
        } else {
            return tag.searchableMetadataString.contains(string)
        }
    }
    
    func filter(by query: String) -> [Tag] {
        var filterPredicate: (Tag) -> Bool = { _ in true }
        if query.isEmpty {
            filterPredicate = { _ in true }
        } else {
            let results = query.split(separator: "|").map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }.map{ $0.split(separator: "&").map{ s in s.trimmingCharacters(in: .whitespacesAndNewlines)} }
            filterPredicate = {
                tag in results.anySatisfy {
                    conjunction in conjunction.allSatisfy {
                        text in
                        return tagMatchesString(string: text, tag: tag)
                        
                    }
                }
            }
        }
        return tags.filter(filterPredicate)
    }
    
    var tagTable: some View {
        Table(of: Tag.self,  selection: $selected, columns: {
//                    TableColumn("Tag") { item in
//                        Text(item.value)
//                    }
            TableColumn("Tag") { item in
                if item.image != nil {
                    HStack {
                        // TODO: thumbnail is blank when first added but back after any view update
                        try? item.ensureThumbnail() =>
                        ImageSelector.imageOfFile(item.thumbnail)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 75, alignment: .center)
                        Spacer()
                        Button {
                            if selected.contains(item.id) {
                                if let selected = selected.first, let url = Tag.tag(fromID: selected)?.image {
                                    qlPreviewLink = url
                                }
                            } else if let url = item.image {
                                qlPreviewLink = url
                            }
                        } label: {
                            Image(systemName: "eye")
                        }
                    }
                } else {
                    Text(item.value)
                }
            }
        }, rows: {
            ForEach(filter(by: query.wrappedValue)) { (item: Tag) in
                TableRow(item)
                    .contextMenu {
                        Button("Rerun Image Recognition") {
                            item.detectText()
                            item.detectObjects()
                        }.disabled(!isImageTagSelected)
                        Button("Show strings") {
                            appState.isShowingStrings = true
                            selected.removeAll()
                            stringTag = item
                        }.disabled(!isImageTagSelected)
                        
                        Divider()
                        Button("Edit") {
                            appState.editing = false
                            appState.isEditingTag = true
                            appState.editTargetTag = item

                        }
                    }
            }
        })
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                if files.count == 1 {
                    Text("Tags for file \(files.first!.id)")
                } else {
                    let s = files.map { $0.filename }.joined(separator: "\n")
                    Label("Tags for \(files.count) files", systemImage: "rectangle.and.text.magnifyingglass")
                        .help(s)
                        .foregroundColor(.accentColor)
                        .onTapGesture {
                            showingHelp = true
                        }
                    Text("This list includes all the tags across all of the selected files. Each tag may not be present on any one individual file. Any tag added in this view will be added to all selected files")
                }
                
                tagTable
                .onDeleteCommand(perform: self.performDelete)
                
                HStack {
                    Picker(selection: $chosenFormat, content: {
                        Text("References").tag(Tag.ImageFormat.url)
                        Text("Image Data").tag(Tag.ImageFormat.content)
                    }, label: {
                        Text("Save Format")
                    }).disabled(
                        selected.count == 0 ||
                        selected.allSatisfy { Tag.tag(fromID: $0)?.image == nil }
                    )
                    Spacer().frame(width: 20.0)
                    Button("Change Formats") {
                        selected.forEach { Tag.tag(fromID: $0)!.imageFormat = chosenFormat }
                    }
                }
               
                if allowAdding {
                    TabView(selection: $selectedView) {
                        addTextView.tabItem({
                            Text("Text")
                        }).tag(ViewSelection.text)
                        
                        addImageView.tabItem({
                            Text("Image")
                        }).tag(ViewSelection.image)
                    }.frame(width: ImageSelector.size.width + 50, height: ImageSelector.size.height + 50)
                    
                    
                    
                    buttonBar
                    Button("Close") {
                        done(files)
                    }.keyboardShortcut(.return, modifiers: [])
                }
            }
        }.frame(minWidth: 500.0, maxWidth: .infinity, minHeight: 500.0, maxHeight: .infinity, alignment: Alignment.center)
            .padding()
            .onAppear {
                appState.createSelectionModel(for: TagView.selectionIdentifier)
                if self.universalView {
                    files = Set(directory.files)
                }
                refresh()
            }
            .onDisappear {
                appState.releaseSelectionModel()
            }
            .onChange(of: appState.doImageRerun, perform: { _ in
                appState.selectionModels.last?.selectedItems.map({ Tag.tag(fromID: $0 as! Tag.ID)! }).forEach { tag in
                    tag.clearImageStrings()
                    tag.detectText()
                    tag.detectObjects()
                }
            })
            .onChange(of: selected, perform: { _ in
                appState.select(only: selected)
                let f = selected.compactMap({ tag in Tag.tag(fromID: tag) })
                if f.allSatisfy({ $0.image != nil }) && f.map({ $0.imageFormat }).allSame() {
                    chosenFormat = f.first?.imageFormat ?? .url
                } else {
                    chosenFormat = .url
                }
            })
            .onDrop(of: ["public.file-url"], isTargeted: $isTargetedForDrop, perform: { b in
                selectedView = .image
                return receiveDroppedImage(from: b)
            })
            .quickLookPreview($qlPreviewLink)
            .sheet(isPresented: $appState.isShowingStrings, content: {
                showingStringsSheet
                
            })
            .sheet(isPresented: $showingHelp, content: {
                FilesEditingInspectorView(done: { showingHelp = false; refresh() }, removeFileWithID: { id in
                    guard let idx = files.firstIndex(where: {$0.id == id}) else { return }
                    files.remove(at: idx)
                }, addFileWithID: {
                    files.insert($0)
                }, files: files)
            })
            .sheet(isPresented: $appState.showingImageImportError, content: {
                Group {
                    Text("Could not import image").font(.title)
                    Text(message)
                    Text("Only files in the following formats are supported")
                    Text("\(TagView.validImageExtensions.joined(separator: ", "))")
                    Button("Close") {
                        appState.showingImageImportError = false
                    }
                }.padding()
            })
    }
    
    func refresh() {
//        if universalView {
//            tags = directory.files.map { $0.tags }.flatten().unique()
//        } else {
            tags = files.map { $0.tags }.flatten().unique()
//        }
        let types = tags.map { $0.imageFormat }.unique()
        if types.count == 1 {
            chosenFormat = types.first!
        } else {
            chosenFormat = .url
        }
        print("Refresh complete, tag count: \(tags.count)")
    }
    
    static let validImageExtensions: Set<String> = ["bmp", "tiff", "png", "jpeg", "jpg", "gif", "dng", "heic"]
    
    func receiveDroppedImage(from providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { data, error in
            if let data, let s = String(data: data, encoding: .utf8), let originalURL = URL(string: s) {
                if TagView.validImageExtensions.contains(originalURL.pathExtension.lowercased()) {
                    do {
                        tagImage = try RetainedImage(url: originalURL, withID: UUID())
                    } catch {
                        message = "Could not access requested image at \(originalURL)"
                        appState.showingImageImportError = true
                    }
                } else {
                    appState.showingImageImportError = true
                }
                
            }
        })
        
        return true
    }
    
    func storeCurrentTag() {
        if (currentTag.isEmpty || currentTag.allSatisfy({$0.isWhitespace})) &&
            !tagImage.isPresent {
            return
        }
        var tag: Tag
        if !tagImage.isPresent {
            tag = Tag.tag(withString: currentTag)
            currentTag = ""
            directory.objectWillChange.send()
        } else {
            do {
                if (tagImage.isPresent) {
                    let newTagFile = try tagImage.persist()
                    tag = Tag.tag(imageURL: newTagFile, thumbnail: nil, imageIdentifier: tagImage.id!)
                    try tagImage.destroy()
                    directory.objectWillChange.send()
                } else {
                    throw AddTagError.generic
                }
            } catch {
                message = "An error occurred while trying to save the image: \(error.localizedDescription)"
                appState.showingImageImportError = true
                return
            }
        }
        do {
            try directory.addTags(tag, toAll: files.map { $0 })
            tags = files.map { $0.tags }.flatten().unique()
        } catch {
            showingError = true
            message = "\(error.localizedDescription): The tag contains an illegal character"
        }
    }
    
    func addCurrentTag() {
        storeCurrentTag()
        // tagWasSet
        if appState.doImageVision {
            directory.imageVisionSet(doVision: true)
        }
    }
}

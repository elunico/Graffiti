//
//  TagView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/4/23.
//

import Foundation
import SwiftUI

struct TagView: View {
    @State var files: Set<TaggedFile>
    @State var selected: Set<Tag.ID> = []
    @State var currentTag: String = ""
    @State var showingHelp = false
    @State var tagImage: URL? = nil
    @State var tagImageThumbnail: URL? = nil
    @State var qlPreviewLink: URL? = nil
    @State var selectedView: ViewSelection = .text
    @EnvironmentObject var directory: TaggedDirectory
    @EnvironmentObject var appState: ApplicationState
    
    @State var chosenFormat: Tag.ImageFormat = .none
    @State var tags: Array<Tag> = []
    
    var prohibitedCharacters: Set<Character>
    var done: (Set<TaggedFile>) -> ()
    
    enum ViewSelection: Hashable {
        case text
        case image
    }
    
    func performDelete()  {
        for index in selected {
            let tag =  Tag.tag(fromID: index)!
            let f = files.filter { $0.tags.contains(tag) }.map { $0 }
            directory.removeTag(withID: index, fromAll: f)
        }
        tags = files.map { $0.tags }.flatten().unique()
        selected = []
    }
    
    func setImage(url: URL, thumbnail thumbnailURL: URL) {
        tagImage = url
        tagImageThumbnail = thumbnailURL
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
                }.disabled(currentTag == "" && tagImage == nil)
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
    
    var addImageView: some View {
        Group {
            ImageSelector(selectedImage: $tagImage, onClick: { _ in
                DispatchQueue.main.async {
                    selectFile(ofTypes: [.image]) { urls in
                        guard let originalURL = urls.first else { return }
                        let (url, thumbnailURL) = try! acquireImage(at: originalURL)
                        setImage(url: url, thumbnail: thumbnailURL)
                    }
                }
            }, onDroppedFile: { (_, providers) in
                return receiveDroppedImage(from: providers)
            })
         
        }
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
                
                Table(tags, selection: $selected, columns: {
                    TableColumn("Tag") { item in
                        if item.image != nil {
                            HStack {
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
                })
                .onDeleteCommand(perform: self.performDelete)
                
                HStack {
                    Picker(selection: $chosenFormat, content: {
                        Text("References").tag(Tag.ImageFormat.url)
                        Text("Image Data").tag(Tag.ImageFormat.content)
                        Text("").tag(Tag.ImageFormat.none).disabled(true)
                    }, label: {
                        Text("Save Format")
                    }).disabled(
                        selected.count == 0 ||
                        selected.allSatisfy { Tag.tag(fromID: $0)?.image == nil }
                    )
                    Spacer().frame(width: 20.0)
                    Button("Change Formats") {
                        selected.forEach { Tag.tag(fromID: $0)!.imageFormat = chosenFormat }
                    }.disabled(chosenFormat == .none)
                }
               
                
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
        }.padding()
            .onAppear {
                appState.createSelectionModel()
                tags = files.map { $0.tags }.flatten().unique()
                chosenFormat = appState.imageSaveFormat
            }
            .onDisappear {
                appState.releaseSelectionModel()
            }
            .onChange(of: selected, perform: { _ in
                appState.select(only: selected)
                let f = selected.compactMap({ tag in Tag.tag(fromID: tag) })
                if f.allSatisfy({ $0.image != nil }) && f.map({ $0.imageFormat }).allSame() {
                    chosenFormat = f.first?.imageFormat ?? .none
                } else {
                    chosenFormat = .none 
                }
            })
            .quickLookPreview($qlPreviewLink)
            .frame(minWidth: 500.0, minHeight: 500.0,  alignment: Alignment.center)
            .sheet(isPresented: $showingHelp, content: {
                FilesEditingInspectorView(done: { showingHelp = false }, removeFileWithID: { id in
                    guard let idx = files.firstIndex(where: {$0.id == id}) else { return }
                    files.remove(at: idx)
                }, addFileWithID: {
                    files.insert($0)
                }, files: files)
            })
            .sheet(isPresented: $appState.showingImageImportError, content: {
                Text("Could not import image").font(.title)
                Text("Only files in the following formats are supported")
                Text("\(TagView.validImageExtensions.joined(separator: ", "))")
            })
    }
    
    static let validImageExtensions: Set<String> = ["bmp", "tiff", "png", "jpeg", "jpg", "gif", "dng", "heic"]
    
    func receiveDroppedImage(from providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { data, error in
            if let data, let s = String(data: data, encoding: .utf8), let originalURL = URL(string: s) {
                if TagView.validImageExtensions.contains(originalURL.pathExtension.lowercased()) {
                    // TODO: handle the error
                    let (url, thumb) = try!  acquireImage(at: originalURL)
                    setImage(url: url, thumbnail: thumb)
                } else {
                    appState.showingImageImportError = true
                }
                
            }
        })
        
        return true
    }
    
    func addCurrentTag() {
        if (currentTag.isEmpty || currentTag.allSatisfy({$0.isWhitespace})) &&
            tagImage == nil {
            return
        }
        var tag: Tag
        if tagImage == nil {
            tag = Tag.tag(withString: currentTag)
            currentTag = ""
        } else {
            tag = Tag.tag(imageURL: tagImage!, thumbnail: tagImageThumbnail!)
            tagImage = nil
        }
        directory.addTags(tag, toAll: files.map { $0 })
        tags = files.map { $0.tags }.flatten().unique()
    }
}

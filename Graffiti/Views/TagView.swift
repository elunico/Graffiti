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
    @State var selected: Tag.ID?
    @State var currentTag: String = ""
    @State var showingHelp = false
//    @State var isDroppingImage = false
    @State var tagImage: URL? = nil
    @State var qlPreviewLink: URL? = nil
    @State var selectedView: ViewSelection = .text
    @EnvironmentObject var directory: TaggedDirectory
    @EnvironmentObject var appState: ApplicationState
    
    var prohibitedCharacters: Set<Character>
    var done: (Set<TaggedFile>) -> ()
    
    enum ViewSelection: Hashable {
        case text
        case image
    }
    
    func performDelete()  {
        guard let index = selected else { return }
        let tag =  Tag.tag(fromID: index)!
        files.forEach { file in print(file.tags.map {$0.id})}
        let f = files.filter { $0.tags.contains(tag) }.map { $0 }
        directory.removeTag(withID: index, fromAll: f)
    }
    
    func setImage(toURL url: URL) {
        tagImage = url
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
                
                Table(files.map { $0.tags }.flatten().unique(), selection: $selected, columns: {
                    TableColumn("Tag") { item in
                        if item.image != nil {
                            HStack {
//                                Image(nsImage: NSImage(byReferencing: item.image!))
                                ImageSelector.imageOfFile(item.image!)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 150, height: 75, alignment: .center)
                                Spacer()
                                Button {
                                    if item.id == selected {
                                        if let selected, selected.tagIDTypePrefix == "IU" {
                                            qlPreviewLink = URL(string: String(selected.tagIDContent))
                                        }
                                    } else if item.id.tagIDTypePrefix == "IU" {
                                        qlPreviewLink = URL(string: String(item.id.tagIDContent))
                                    }
                                } label: {
                                    Image(systemName: "eye")
                                }
                                    
                            }
                        } else {
                            Text(item.value)
                        }
                    }
                }).onDeleteCommand(perform: self.performDelete)
                
                
                TabView(selection: $selectedView) {
                    HStack {
                        Spacer()
                        
                        TextField("Add Tag", text: $currentTag, prompt: Text("Tag"))
                            .onChange(of: currentTag) { _ in
                                currentTag.removeAll(where: { prohibitedCharacters.contains($0) })
                            }.onSubmit {
                                self.addCurrentTag()
                            }
                        Spacer()
                        
                    }.tabItem({
                        Text("Text")
                    }).tag(ViewSelection.text)
                    
                    Group {
                        ImageSelector(selectedImage: $tagImage, onClick: { _ in
                            DispatchQueue.main.async {
                                selectFile(ofTypes: [.image]) { urls in
                                    guard let originalURL = urls.first else { return }
//                                    if appState.copyOwnedImages {
                                        let url = try!  takeOwnership(of: originalURL)
                                        setImage(toURL: url)
                                        
//                                    } else {
//                                        setImage(toURL: originalURL)
//                                    }
                                }
                            }
                        }, onDroppedFile: { (_, providers) in
                            return receiveDroppedImage(from: providers)
                        })
                     
                    }.tabItem({
                        Text("Image")
                    }).tag(ViewSelection.image)
                }
                
                
                
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
                        }.disabled(selected == nil)
                        Button("Add Tag") {
                            self.addCurrentTag()
                        }.disabled(currentTag == "" && tagImage == nil)
                    }
                }
                Button("Close") {
                    done(files)
                }.keyboardShortcut(.return, modifiers: [])
            }
        }.padding()
            .onAppear {
                appState.createSelectionModel()
            }
            .onDisappear {
                appState.releaseSelectionModel()
            }
            .onChange(of: selected, perform: { _ in
                if let id = selected {
                    appState.select(only: id)
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
    }
    
    static let validImageExtensions: Set<String> = ["bmp", "tiff", "png", "jpeg", "jpg", "gif", "dng"]
    
    func receiveDroppedImage(from providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { data, error in
            if let data, let s = String(data: data, encoding: .utf8), let originalURL = URL(string: s) {
                if TagView.validImageExtensions.contains(originalURL.pathExtension.lowercased()) {
                    // TODO: handle the error
//                    if appState.copyOwnedImages {
                        let url = try!  takeOwnership(of: originalURL)
                        setImage(toURL: url)
                        
//                    } else {
//                        setImage(toURL: originalURL)
//                    }
                } else {
                    // TODO: alert user
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
            tag = Tag.tag(imageURL: tagImage!, format: appState.imageSaveFormat == .content ? .content : .url)
            tagImage = nil
        }
        directory.addTags(tag, toAll: files.map { $0 })
    }
}

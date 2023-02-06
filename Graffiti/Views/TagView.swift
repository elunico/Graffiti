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
    @EnvironmentObject var directory: TaggedDirectory
    @EnvironmentObject var appState: ApplicationState
    
    var prohibitedCharacters: Set<Character>
    var done: (Set<TaggedFile>) -> ()
    
    func performDelete() {
        guard let index = selected else { return }
        let tag = Tag(value: index)
        directory.removeTag(withID: index, fromAll: files.filter { $0.tags.contains(tag) })
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
                    TableColumn("Tag", value: \Tag.value)
                }).onDeleteCommand(perform: self.performDelete)
                
                
                TextField("Add Tag", text: $currentTag, prompt: Text("Tag"))
                    .onChange(of: currentTag) { _ in
                        currentTag.removeAll(where: { prohibitedCharacters.contains($0) })
                    }.onSubmit {
                        self.addCurrentTag()
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
                        }.disabled(currentTag == "")
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
    
    func addCurrentTag() {
        if currentTag.isEmpty || currentTag.allSatisfy({$0.isWhitespace}) {
            return
        }
        let tag = Tag(value: currentTag)
        directory.addTags(tag, toAll: files.map { $0 })
        
        currentTag = ""
    }
}

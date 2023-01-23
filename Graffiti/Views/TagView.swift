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
    var prohibitedCharacters: Set<Character>
    var done: (Set<TaggedFile>) -> ()
    
    func performDelete() {
        guard let index = selected else { return }
        files.forEach{ $0.removeTag(withID: index) }
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
                    Button("Add Tag") {
                        self.addCurrentTag()
                    }.disabled(currentTag == "")
                    Spacer()
                    Button("Delete Tag") {
                        self.performDelete()
                    }.disabled(selected == nil)
                }.padding()
                Button("Close") {
                    done(files)
                }.keyboardShortcut(.return, modifiers: [])
            }
        }.padding()
            .frame(minWidth: 500.0, minHeight: 500.0,  alignment: Alignment.center)
            .sheet(isPresented: $showingHelp, content: {
                FilesEditingInspectorView(done: { showingHelp = false }, removeFileWithID: { id in files.remove(at: files.firstIndex(where: {$0.id == id})!) }, files: files)
            })
    }
    
    func addCurrentTag() {
        if currentTag.isEmpty || currentTag.allSatisfy({$0.isWhitespace}) {
            return
        }
        
        files.forEach { $0.addTag(Tag(value: currentTag)) }
        currentTag = ""
    }
}

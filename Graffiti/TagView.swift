//
//  TagView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/4/23.
//

import Foundation
import SwiftUI

struct TagView: View {
    @StateObject var file: TaggedFile
    @State var selected: Tag.ID?
    @State var currentTag: String = ""
    var done: (TaggedFile) -> ()
    
    func performDelete() {
        guard let index = selected else { return }
        file.removeTag(withID: index)
    }
    
    var body: some View {
        VStack {
            Text("Tags for file \(file.id)")
            
            Table(file.tags, selection: $selected, columns: {
                TableColumn("Tag", value: \Tag.value)
            }).onDeleteCommand(perform: self.performDelete)
            
            TextField("Add Tag", text: $currentTag, prompt: Text("Tag"))
                .onChange(of: currentTag) { _ in
                // all credits to Leo Dabus:
                currentTag.removeAll(where: {  ",&|!".contains($0) })
                    
                }
            
            HStack {
                Button("Add Tag") {
                    if currentTag.isEmpty || currentTag.allSatisfy({$0.isWhitespace}) {
                        return
                    }
                    
                    file.addTag(Tag(value: currentTag))
                    currentTag = ""
                }.disabled(currentTag == "")
                Spacer()
                Button("Delete Tag") {
                    self.performDelete()
                }.disabled(selected == nil)
            }.padding()
            Button("Close") {
                file.objectWillChange.send()
                done(file)
            }
        }.padding()
    }
}

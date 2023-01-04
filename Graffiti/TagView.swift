//
//  TagView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/4/23.
//

import Foundation
import SwiftUI

extension Array where Element: Sequence {
    func flatten() -> Array<Element.Element> {
        var result = [Element.Element]()
        for elt in self {
            for item in elt {
                result.append(item)
            }
        }
        return result
    }
}

extension Array where Element: Hashable {
    func unique() -> Array<Element> {
        var result = [Element]()
        var checker = Set<Element>()
        for elt in self {
            if !checker.contains(elt) {
                result.append(elt)
                checker.insert(elt)
            }
        }
        return result
    }
}

struct TagView: View {
    @State var files: Set<TaggedFile>
    @State var selected: Tag.ID?
    @State var currentTag: String = ""
    var done: (Set<TaggedFile>) -> ()
    
    func performDelete() {
        guard let index = selected else { return }
        files.forEach{ $0.removeTag(withID: index) }
    }
    
    var body: some View {
        VStack {
            if files.count == 1 {
                Text("Tags for file \(files.first!.id)")
            } else {
                let s = files.map { $0.filename }.joined(separator: "\n")
                Text("Tags for \(files.count) files")
                    .help("Files:\n\(s)")
                Text("This list includes all the tags across all of the selected files.")
                Text("Each tag may not be present on any one individual file.")
                Text("Any tag added in this view will be added to all selected files")
            }
            
            Table(files.map { $0.tags }.flatten().unique(), selection: $selected, columns: {
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
                    
                    files.forEach { $0.addTag(Tag(value: currentTag)) }
                    currentTag = ""
                }.disabled(currentTag == "")
                Spacer()
                Button("Delete Tag") {
                    self.performDelete()
                }.disabled(selected == nil)
            }.padding()
            Button("Close") {
                done(files)
            }
        }.padding()
    }
}

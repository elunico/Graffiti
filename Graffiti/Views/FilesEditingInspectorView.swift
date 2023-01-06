//
//  FilesEditingInspectorView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/5/23.
//

import Foundation
import SwiftUI

struct FilesEditingInspectorView: View {
    @State var selectedFile: TaggedFile.ID? = nil
    @State var done: () -> ()
    var removeFileWithID: (TaggedFile.ID) -> ()
    var files: Set<TaggedFile>
    
    var body: some View {
        VStack {
            Text("Files Being Edited")
                .font(.headline)
            Table(files.map{ $0 }, selection: $selectedFile, columns: {
                TableColumn("Filename", value: \TaggedFile.filename)
            })
            Button("Exclude File") {
                guard let id = selectedFile else { return  }
                removeFileWithID(id)
            }.disabled(selectedFile == nil)
            Text("Note that you can view this list of files by hovering over the 'Tags of n files' text")
                .font(.caption2)
            Button("Close") {
                done()
            }
            
        }.padding()
            .frame(minHeight: 400.0)
    }
}

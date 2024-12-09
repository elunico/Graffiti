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
    var addFileWithID: (TaggedFile) -> ()
    @State var files: Set<TaggedFile>
    @EnvironmentObject var appState: ApplicationState
    var externalSelectionModel = AnySelectionModel()

    @State var removedFiles: [TaggedFile] = []
    
    static var selectionIdentifier = "file-editing-view"
    
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
                var fit = files.makeIterator()
                var p: TaggedFile? = nil
                while var f = fit.next() {
                    p = f
                    if selectedFile == f.id {
                        files.remove(f)
                        removedFiles.append(f)
                        selectedFile = fit.next()?.id
                        if selectedFile == nil {
                            selectedFile = p?.id
                        }
                        break
                    }
                }
            }.disabled(selectedFile == nil)
            Button("Undo") {
                if let last = removedFiles.popLast() {
                    addFileWithID(last)
                    files.insert(last)
                }
            }.disabled(removedFiles.isEmpty)
                .keyboardShortcut("z", modifiers: [.command])
            Text("Warning: exclusions cannot be undone if the sheet is closed")
                .font(.caption2)
            Button("Close") {
                done()
            }
            
        }.padding()
            .frame(minHeight: 400.0)
            .onAppear {
                appState.createSelectionModel(for: FilesEditingInspectorView.selectionIdentifier)
            }
            .onDisappear {
                appState.releaseSelectionModel()
            }
            .onChange(of: selectedFile, perform: { _ in
                if let id = selectedFile {
                    appState.select(only: id)
                }
            })
    }
}

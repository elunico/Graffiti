//
//  ContentView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 12/31/22.
//

import SwiftUI

extension URL {
    var absolutePath: String {
        absoluteString.replacingOccurrences(of: "file://", with: "")
    }
}

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


struct ContentView: View {
    @State var directory: URL? = nil
    @State var files: [TaggedFile] = []
    @State var selected: TaggedFile.ID?
    @State var editing: Bool = false
    @State var needsUpdate: Bool = false
    
    @State var isPresentingConfirm: Bool = false
    
    var body: some View {
        VStack {
            Button("Choose Directory") {
                selectFolder {
                    directory = $0[0]
                    let content = try! FileManager().contentsOfDirectory(atPath: directory!.absolutePath)
                    self.files = content.map { TaggedFile(parent: directory!.absolutePath, filename: $0, backend: LazyBackend(wrapping: XattrTagBackend())) }
                }
            }
            Text("Tagging: \(directory?.absoluteString ?? "<none>")")
            Table(files, selection: $selected, columns: {
                TableColumn("Path", value: \TaggedFile.id)
                TableColumn("Tags", value: \TaggedFile.tagString)
                TableColumn("Count", value: \TaggedFile.tagCount)
            })
            Button("Edit Tags") {
                guard selected != nil else { return }
                editing = true
            }.disabled(selected == nil)
            Spacer()
            Button("Clear All Tags") {
                isPresentingConfirm = true
            }
            
        }
        .confirmationDialog("Do you want to clear ALL tags",
                            isPresented: $isPresentingConfirm) {
            Button("Clear All") {
                for file in files {
                    file.clearTags()
                }
            }
        } message: {
            Text("This will remove EVERY tag from EVERY file in this directory\nYou cannot undo this action")
        }
        .sheet(isPresented: $editing, onDismiss: {
            needsUpdate.toggle()
            print(files.first(where: {$0.id == selected})!.tags)
        }, content: {
            TagView(file: files.first(where: {$0.id == selected})!, done: { editing = false;  $0.objectWillChange.send(); needsUpdate.toggle() })
        })
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification), perform: { output in
            for taggedFile in files {
                taggedFile.commit()
            }
        })
        .padding()
    }
}

func selectFolder(callback: @escaping ([URL]) -> ()) {
    
    let folderChooserPoint = CGPoint(x: 0, y: 0)
    let folderChooserSize = CGSize(width: 500, height: 600)
    let folderChooserRectangle = CGRect(origin: folderChooserPoint, size: folderChooserSize)
    let folderPicker = NSOpenPanel(contentRect: folderChooserRectangle, styleMask: .utilityWindow, backing: .buffered, defer: true)
    
    folderPicker.canChooseDirectories = true
    folderPicker.canChooseFiles = false
    folderPicker.allowsMultipleSelection = false
    folderPicker.canDownloadUbiquitousContents = true
    folderPicker.canResolveUbiquitousConflicts = true
    
    folderPicker.begin { response in
        
        if response == .OK {
            callback(folderPicker.urls)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

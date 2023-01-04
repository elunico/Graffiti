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

extension View {
    func onClearAll(message: String, isPresented: Binding<Bool>, clearAction: @escaping () -> ()) -> some View {
        self.confirmationDialog("Are you sure you want to clear all?",
                            isPresented: isPresented) {
            Button("Clear All") {
                clearAction()
            }
        } message: {
            Text(message)
        }
    }
}

struct ContentView: View {
    @State var directory: URL? = nil
    @StateObject var files: TaggedDirectory = .empty
    @State var selected: TaggedFile.ID?
    @State var query: String = ""
    
    @State var editing: Bool = false
    @State var isPresentingConfirm: Bool = false
    
    @State var dummy: String = ""
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Button("Choose Directory") {
                    selectFolder {
                        self.directory = $0[0]
                        self.files.load(directory: $0[0].absolutePath, backend: LazyBackend(wrapping: XattrTagBackend()))
                    }
                }
                HStack {
                    Text("Tagging: \(directory?.absoluteString ?? "<none>")")
                    Spacer()
                    TextField("Search", text: $query)
                        .frame(minWidth: 25.0, idealWidth: geometry.size.width / 8, maxWidth: 300.0, alignment: .topTrailing)
                        .help("Enter your search term. Use & and | for boolean operations. Use !word to avoid 'word' in results ")
                }
                Table(files.filter(query: query), selection: $selected, columns: {
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
            .onClearAll(message: "This will remove EVERY tag from EVERY file in this directory\nYou cannot undo this action", isPresented: $isPresentingConfirm, clearAction: {
                for file in files.filter(query: query) {
                    file.clearTags()
                }
            })
            .sheet(isPresented: $editing, onDismiss: {
                print(files.getFile(withID: selected!)!.tags)
            }, content: {
                TagView(file: files.getFile(withID: selected!)!, done: { _ in editing = false })
            })
        }
        .onDisappear(perform: self.teardown)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification), perform: {output in self.teardown()})
        .padding()
    }
        
    
    func teardown() {
        for file in files.files {
            file.commit()
        }
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

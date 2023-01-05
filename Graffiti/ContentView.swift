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
    enum Choice: Hashable {
        case json, plist, xattr
        case none
    }
    
    @State var formatChoice: Choice = .xattr
    @State var lazyChoice: Bool = false
    @State var showingOptions: Bool = true
    
    var body: some View {
        if showingOptions {
            GeometryReader { geometry in
                VStack {
                    Text("Choose a save format")
                    Picker("Format", selection: $formatChoice, content: {
                        Text("JSON File").tag(Choice.json).disabled(true) // not implemented
                        Text("plist File").tag(Choice.plist).disabled(true)  // not implemented
                        Text("xattr attributes").tag(Choice.xattr)
                    })
                    Toggle(isOn: $lazyChoice, label: {
                        Text("Lazy Writing?")
                    })
                    Button("Go!") {
                        showingOptions = false
                    }
                }.padding()
            }
        } else {
            
            let backend: TagBackend = ({
                var backend: TagBackend
                if formatChoice == .xattr {
                    backend = XattrTagBackend()
                } else {
                    fatalError()
                }
                
                if lazyChoice {
                    backend = LazyBackend(wrapping: backend)
                }
                return backend
            })()
            
            MainView(backend: backend, showOptions: { showingOptions = true })
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

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}

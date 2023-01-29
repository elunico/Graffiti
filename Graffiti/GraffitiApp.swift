//
//  GraffitiApp.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 12/31/22.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    var compressedCustomTagStore: UTType { UTType(exportedAs: "com.tom.ccts") }
}

extension Dictionary {
    func tryGet(_ key: Key?) -> Value? {
        if let key {
            return self[key]
        } else {
            return nil
        }
    }
}

class WindowStateManager: ObservableObject {
    @Published var windowStates: [NSUserInterfaceItemIdentifier: (ApplicationState, TaggedDirectory)] = [:]
}

@main
struct GraffitiApp: App {
    
    @StateObject var taggedDirectory: TaggedDirectory = TaggedDirectory.empty.copy() as! TaggedDirectory
    @StateObject var appState: ApplicationState = ApplicationState()
    //    @StateObject var windowStateManager = WindowStateManager()
    
    //    @State var keyWindow: NSUserInterfaceItemIdentifier? = nil
    
    var body: some Scene {
        Window("Graffiti", id: "mainwindow") {
            //        WindowGroup {
            ContentView().environmentObject(appState).environmentObject(taggedDirectory)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
            //            let d = windowStateManager.windowStates.tryGet(keyWindow)?.1 ?? TaggedDirectory.empty.copy() as! TaggedDirectory
            //            let a = windowStateManager.windowStates.tryGet(keyWindow)?.0 ?? ApplicationState()
            //            ContentView().environmentObject(d).environmentObject(a)
            //                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            //                    print(notification.object as? NSWindow)
            //                    if let window = notification.object as? NSWindow, let keyIdentifier = window.identifier {
            //                        keyWindow = keyIdentifier
            //                        print(keyWindow)
            //                        print(windowStateManager.windowStates[keyIdentifier])
            //                        windowStateManager.windowStates[keyIdentifier] = (ApplicationState(), TaggedDirectory.empty.copy() as! TaggedDirectory)
            //                    }
            //                }
            
        }
        
        .commands(content: {
            CommandMenu("Tags", content: {
                Button("Edit Tags") {
                    appState.currentState = .EditingTags
                    appState.editing = true
                }.disabled(canEditTags)
                    .keyboardShortcut("e")
                Button("Clear All Tags") {
                    appState.currentState = .ShowingConfirm
                    appState.isPresentingConfirm = true
                }.disabled(canEditTags)
                    .keyboardShortcut(.delete, modifiers: [.control, .command])
            })
            CommandGroup(after: .newItem, addition: {
                Button("Open File(s)", action: {
                    
                    if let files = appState.selectionModels.last?.selectedItems.map({ $0 as? TaggedFile.ID }).droppingNils() {
                        for file in files {
                            NSWorkspace.shared.open(URL(fileURLWithPath: file))
                        }
                    }
                    
                }).keyboardShortcut(.downArrow, modifiers: [.command])
                    .disabled((appState.selectionModels.last?.selectedItems.first as? TaggedFile.ID) == nil)
                
                Button("Reveal File") {
                    if let file = appState.selectionModels.last?.selectedItems.map({ $0 as? TaggedFile.ID }).droppingNils().first {
                        if !NSWorkspace.shared.selectFile(file, inFileViewerRootedAtPath: (file as NSString).deletingLastPathComponent) {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: (file as NSString).deletingLastPathComponent)
                        }
                    }
                }.keyboardShortcut(.return, modifiers: [.command])
                    .disabled(appState.selectionModels.last?.selectedItems.count != 1 || (appState.selectionModels.last?.selectedItems.first as? TaggedFile.ID) == nil)
                
                Divider()
                
                Button("Reveal Current Folder in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: taggedDirectory.directory)
                }.disabled(taggedDirectory.directory.isEmpty)
                
                Button("Reveal Current Tag Store File in Finder") {
                    if let file = taggedDirectory.tagStore {
                        if !NSWorkspace.shared.selectFile(file, inFileViewerRootedAtPath: taggedDirectory.directory) {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: taggedDirectory.directory)
                        }
                    }
                }.disabled(taggedDirectory.tagStore == nil)
                
                
            })
            
            
        }).keyboardShortcut("0")
        
        Window("Convert a Tag Store File", id: "convertwindow", content: {
            ConvertView()
        }).keyboardShortcut("1")
    }
    
    var canEditTags: Bool {
        switch appState.currentState {
        case .MainView(let t):
            return !t
        default:
            return true
        }
    }
    
}

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

@main
struct GraffitiApp: App {
    
    @StateObject var taggedDirectory: TaggedDirectory = TaggedDirectory.empty.copy() as! TaggedDirectory
    @StateObject var appState: ApplicationState = ApplicationState()
    
    func editTags() {
        appState.currentState = .EditingTags
        appState.editing = true
    }
    
    func clearAllTags() {
        appState.currentState = .ShowingConfirm
        appState.isPresentingConfirm = true
    }
    
    func openFiles() {
        
        if let files = appState.selectionModels.last?.selectedItems.compactMap({ $0 as? TaggedFile.ID }) {
            for file in files {
                NSWorkspace.shared.open(URL(fileURLWithPath: file))
            }
        }
    }
    
    func revealFiles() {
        if let file = appState.selectionModels.last?.selectedItems.compactMap({ $0 as? TaggedFile.ID }).first {
            if !NSWorkspace.shared.selectFile(file, inFileViewerRootedAtPath: (file as NSString).deletingLastPathComponent) {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: (file as NSString).deletingLastPathComponent)
            }
        }
    }
    
    func revealCurrentFolder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: taggedDirectory.directory)
    }
    
    func revealCurrentTagStore() {
        if let file = taggedDirectory.tagStore {
            if !NSWorkspace.shared.selectFile(file, inFileViewerRootedAtPath: taggedDirectory.directory) {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: taggedDirectory.directory)
            }
        }
    }
    
    var keyWindow: NSWindow? {
        NSApp.keyWindow ?? NSApplication.shared.windows.filter {$0.isKeyWindow}.first
    }
    
    var body: some Scene {
        Window("Graffiti", id: "mainwindow") {
            //        WindowGroup {
            ContentView().environmentObject(appState).environmentObject(taggedDirectory)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        
        .commands(content: {
            CommandMenu("Tags", content: {
                Button("Edit Tags") {
                    editTags()
                }
                .disabled(canEditTags)
                    .keyboardShortcut("e")
                Button("Clear All Tags") {
                    clearAllTags()
                }.disabled(canEditTags)
                    .keyboardShortcut(.delete, modifiers: [.control, .command])
            })
            CommandGroup(after: .newItem, addition: {
                Button("Open File(s)", action: {
                    openFiles()
                }).keyboardShortcut(.downArrow, modifiers: [.command])
                    .disabled((appState.selectionModels.last?.selectedItems.first as? TaggedFile.ID) == nil)
                
                Button("Reveal File") {
                    revealFiles()
                }.keyboardShortcut(.return, modifiers: [.command])
                    .disabled(appState.selectionModels.last?.selectedItems.count != 1 || (appState.selectionModels.last?.selectedItems.first as? TaggedFile.ID) == nil)
                
                Divider()
                
                Button("Reveal Current Folder in Finder") {
                    revealCurrentFolder()
                }.disabled(taggedDirectory.directory.isEmpty)
                
                Button("Reveal Current Tag Store File in Finder") {
                    revealCurrentTagStore()
                }.disabled(taggedDirectory.tagStore == nil)
            })
            
            
        }).keyboardShortcut("0")
        
        Window("Convert a Tag Store File", id: "convertwindow", content: {
            ConvertView()
        }).keyboardShortcut("1")
        
        
        Window("Statistics", id: "statisticswindow") {
            TagCharts().environmentObject(taggedDirectory)
        }.keyboardShortcut("9")
    
        Settings {
            
            SettingsView().environmentObject(appState).environmentObject(taggedDirectory)
        }
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

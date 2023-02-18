//
//  ContentView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 12/31/22.
//

import SwiftUI
import UniformTypeIdentifiers



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
    
    
    @EnvironmentObject var taggedDirectory: TaggedDirectory
    @EnvironmentObject var appState: ApplicationState
    @State var formatChoice: Format = .none
    @State var lazyChoice: Bool = false
    //    @State var showingOptions: Bool = true
    @State var showingError: Bool = false
    @State var loadedFile: URL? = nil
    @State var directory: URL? = nil
    //    @State var isImporting: Bool = false
    //    @State var isConverting: Bool = false
    //    @State var isLoading: Bool = false {
    //        didSet {
    //            if !isLoading {
    //                NSApplication.shared.requestUserAttention(.informationalRequest)
    //            }
    //        }
    //    }
    
    @State var targeted: Bool = false
    @State var errorString: String = ""
    
    @Environment(\.openWindow) private var openWindow
    
    var optionArea: some View {
        Group {
            Group {
                Label("Choose a directory", systemImage: "1.circle")
                    .font(.title)
                Text("Drag and drop an existing plist or csv tag store \nor drag and a drop a directory, or use the button to get started").font(.subheadline).padding()
                Button("Choose Directory") {
                    selectFolder {
                        self.directory = $0[0]
                    }
                }
                Text("Selected: \(directory?.absolutePath ?? "<none>")")
            }
            Spacer().frame(height: 25.0)
            Label("Choose a save format", systemImage: "2.circle")
                .font(.title)
            FormatSelector(formatChoice: $formatChoice)
            Toggle(isOn: $lazyChoice, label: {
                Text("Lazy Writing?")
            })
            Spacer().frame(height: 25.0)
        }
    }
    
    var selectionView: some View {
        GeometryReader { geometry in
            VStack {
                Group {
                    Text("Graffiti").font(.largeTitle)
                    Text("A File Tagging Application").font(.title2)
                    Divider().frame(width: geometry.size.width / 2)
                }
                optionArea
                Label("Start Tagging!", systemImage: "3.circle")
                    .font(.title)
                Button {
                    if directory != nil && formatChoice != .none {
                        self.loadUserSelection { [unowned appState] in
                            appState.showingOptions = !$0
                        }
                    }
                } label: {
                    Label("Go!", systemImage: "arrowshape.forward")
                }.disabled(directory == nil || formatChoice == .none)
                Spacer().frame(height: 50.0)
                Divider().frame(width: geometry.size.width / 2)
                Button("Convert an existing tag store") {
                    openWindow(id: "convertwindow")
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .padding()
        }
        .onDrop(of: ["public.file-url"], isTargeted: $targeted) { providers -> Bool in
            receiveDrop(providers: providers)
            return true
        }
        .frame(minWidth: 600.0, minHeight: 650.0, alignment: .center)
        .sheet(isPresented: $showingError, content: {
            VStack {
                Text("Error").font(.title).padding()
                Text(errorString)
                HStack {
                    Button("Close") {
                        showingError = false
                    }
                    if let ext = formatChoice.fileExtension, let url = directory?.appendingPathComponent("\(FileTagBackend.filePrefix).\(ext)") {
                        Button("Delete File") {
                            // TODO: oh boy
                            if (try? FileManager.default.removeItem(at: url)) == nil {
                                showingError = true
                            } else {
                                showingError = false
                                loadUserSelection { [unowned appState] in
                                    appState.showingOptions = !$0
                                }
                            }
                        }
                    }
                }
            }.padding()
        })
    }
    
    
    
    var body: some View {
        if appState.isLoading {
            ProgressView().progressViewStyle(CircularProgressViewStyle()).onAppear {
                loadDefaultSettings(to: appState)            }
        } else if appState.showingOptions {
            selectionView
                .fileImporter(
                    isPresented: $appState.isImporting,
                    allowedContentTypes: [.plainText],
                    allowsMultipleSelection: false
                ) { result in
                    do {
                        guard let selectedFile: URL = try result.get().first else { return }
                        if FileManager.default.fileExists(atPath: selectedFile.absolutePath) {
                            loadDroppedFile(selectedFile)
                        }
                        
                    } catch {
                        // Handle failure.
                        print("Unable to read file contents")
                        print(error.localizedDescription)
                    }
                }
                .onOpenURL(perform: { [unowned appState] path in
                    appState.isLoading = true
                    appState.currentState = .Loading
                    loadDroppedFile(path)
                    
                }).onAppear {
                    loadDefaultSettings(to: appState)
                }
        } else {
            MainView(choice: formatChoice, directory: self.directory)
            .onAppear {
                loadDefaultSettings(to: appState)
            }.onDisappear {
                formatChoice = .none
            }
            
        }
        
    }
    
    func loadUserSelection(onDone completed: @escaping (_ success: Bool) -> Void) {
        appState.isLoading = true
                
        DispatchQueue.main.async {
            guard let dir = self.directory else { return completed(false) }
            let filename = loadedFile == nil ? nil : NSString(string: loadedFile!.lastPathComponent).deletingPathExtension
            
            do {
                try  taggedDirectory.load(directory: dir.absolutePath, filename: filename, format: formatChoice)
                appState.isLoading = false
                showingError = false
                appState.currentState = .MainView(hasSelection: false)
                completed(true)
            } catch FileWriterError.IsADirectory {
                appState.isLoading = false
                errorString = "The path \(dir.absolutePath) is a directory not a file"
                showingError = true
                appState.currentState = .ShowingFileError
                completed(false)
            } catch FileWriterError.DeniedFileAccess {
                appState.isLoading = false
                errorString = "Graffiti does not have permission to open the chosen file or directory"
                showingError = true
                appState.currentState = .ShowingFileError
                completed(false)
            } catch FileWriterError.InvalidFileFormat {
                appState.isLoading = false
                errorString = "The file chosen has an invalid format."
                showingError = true
                appState.currentState = .ShowingFileError
                completed(false)
            } catch FileWriterError.VersionMismatch {
                errorString = "The file chosen is from an old version of Graffiti and cannot be opened"
                showingError = true
                appState.isLoading = false
                appState.currentState = .ShowingFileError
                completed(false)
            } catch let error {
                print(error)
                errorString = "An unknown error occurred"
                showingError = true
                appState.isLoading = false
                appState.currentState = .ShowingFileError
                completed(false)
            }
        }
    }
    
    func loadDroppedFile(_ url: URL) {
        DispatchQueue.main.async {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.absolutePath, isDirectory: &isDir) && isDir.boolValue {
                directory = url
                loadedFile = nil
                formatChoice = .none
            } else {
                loadedFile = url
                var matchedImport = false
                for format in Format.allCases {
                    if let f = format.fileExtension, url.pathExtension == f {
                        directory = url.deletingLastPathComponent()
                        formatChoice = format
                        self.loadUserSelection { [unowned appState] success in
                            if success {
                                appState.showingOptions = false
                                showingError = false
                            } else {
                                appState.showingOptions = true
                                showingError = true
                            }
                        }
                        matchedImport = true
                        break
                    }
                }
                if !matchedImport {
                    errorString = "The selected file format is not a Tag Store File format"
                    showingError = true
                    appState.isLoading = false
                    appState.currentState = .ShowingFileError
                }
            }
        }
    }
    
    func receiveDrop(providers: [NSItemProvider]) {
        providers.first?.loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { (data, error) in
            if let data = data, let path = String(data: data, encoding: .utf8), let url = URL(string: path) {
                loadDroppedFile(url)
            }
        })
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

func selectFile(ofTypes types: [UTType], callback: @escaping ([URL]) -> ()) {
    
    let folderChooserPoint = CGPoint(x: 0, y: 0)
    let folderChooserSize = CGSize(width: 500, height: 600)
    let folderChooserRectangle = CGRect(origin: folderChooserPoint, size: folderChooserSize)
    let filePicker = NSOpenPanel(contentRect: folderChooserRectangle, styleMask: .utilityWindow, backing: .buffered, defer: true)
    
    filePicker.canChooseDirectories = false
    filePicker.canChooseFiles = true
    filePicker.allowsMultipleSelection = false
    filePicker.canDownloadUbiquitousContents = true
    filePicker.canResolveUbiquitousConflicts = true
    filePicker.allowedContentTypes = types
    
    filePicker.begin { response in
        if response == .OK {
            callback(filePicker.urls)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


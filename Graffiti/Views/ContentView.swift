//
//  ContentView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 12/31/22.
//

import SwiftUI
import UniformTypeIdentifiers


struct ContentView: View {
    
    
    @EnvironmentObject var taggedDirectory: TaggedDirectory
    @EnvironmentObject var appState: ApplicationState
    @State var formatChoice: Format = .none
    @State var lazyChoice: Bool = false
    
    @State var showingError: Bool = false
    @State var loadedFile: URL? = nil
    @State var directory: URL? = nil
    
    @State var targeted: Bool = false
    @State var errorString: String = ""
    
    @State var promptAutosaveRestore: Bool = false
    @State var doLoadFromAutosave: Bool = false
    
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
                        
                        //                        self.loadUserSelection { [unowned appState] in
                        //                            appState.showingOptions = !$0
                        //                        }
                    }
                } label: {
                    Label("Go!", systemImage: "arrowshape.forward")
                }.disabled(directory == nil || formatChoice == .none)
                Spacer().frame(height: 50.0)
                Divider().frame(width: geometry.size.width / 2)
                Text("Other Options").font(.title)
                Button("Convert an existing tag store") {
                    openWindow(id: "convertwindow")
                }
                Button("Resize an image") {
                    openWindow(id: "imageresizewindow")
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
            .sheet(isPresented: $promptAutosaveRestore, content: {
                VStack {
                    Text("There is an autosave file present. Would you like to restore this autosave? Previous data will be removed.")
                    Button(action: {
                        doLoadFromAutosave = true
                        self.finishLoadUserSelection(onDone: completeLoadOfFile)
                    }, label: {
                        Text("Load autosaved data")
                    })
                    Button(action: {
                        doLoadFromAutosave = false
                        self.finishLoadUserSelection(onDone: completeLoadOfFile)
                    }, label: {
                        Text("Remove autosave data and continue with prior data")
                    })
                }.padding()
            })
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
    
    static var defaultFilename: String {
        "com-tom-graffiti.tagfile"
    }
    
    func finishLoadUserSelection(onDone completed: @escaping (_ success: Bool) -> Void) {
        let dir = self.directory!
        let filename = loadedFile == nil ? ContentView.defaultFilename : NSString(string: loadedFile!.lastPathComponent).deletingPathExtension
        do {
            if doLoadFromAutosave {
                try taggedDirectory.loadAutosave(directory: dir.absolutePath, filename: filename, format: formatChoice)
            } else {
                taggedDirectory.removeAutosave()
                try taggedDirectory.load(directory: dir.absolutePath, filename: filename, format: formatChoice)
            }
            appState.isLoading = false
            showingError = false
            appState.currentState = .MainView(hasSelection: false)
            completed(true)
        }
        catch FileWriterError.IsADirectory {
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
    
    func loadUserSelection(onDone completed: @escaping (_ success: Bool) -> Void) {
        appState.isLoading = true
        
        DispatchQueue.main.async {
            guard let dir = self.directory else { return completed(false) }
            let filename = loadedFile == nil ? ContentView.defaultFilename : NSString(string: loadedFile!.lastPathComponent).deletingPathExtension
            print("Load user selection filename is \(filename)")
            
            taggedDirectory.setBackend(directory: dir.absolutePath, filename: filename, format: formatChoice)
            
            if taggedDirectory.hasTemporaryAutosave() {
                promptAutosaveRestore = true
            } else {
                self.finishLoadUserSelection(onDone: completed)
            }
        }
    }
    
    func completeLoadOfFile(success: Bool) {
        if success {
            appState.showingOptions = false
            showingError = false
        } else {
            appState.showingOptions = true
            showingError = true
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
                        print("before loadUserSelection loadedFile \(loadedFile)")
                        self.loadUserSelection(onDone: completeLoadOfFile)
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


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


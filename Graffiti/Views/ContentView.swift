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
    enum Format: Hashable, CustomStringConvertible, CaseIterable {
        var description: String {
            switch self {
            case .plist: return "Property List"
            case .csv: return "Comma-Separated Values"
            case .xattr: return "Extended File Attributes"
            case .json: return "JSON File"
            case .ccts: return "Custom Compressed Tag Store"
            case .none: return "<<none>>"
            }
        }
        
        var fileExtension: String? {
            switch self {
            case .plist: return "plist"
            case .csv: return "csv"
            case .json: return "json"
            case .xattr: return nil
            case .none: return nil
            case .ccts: return "ccts"
            }
        }
        
        func implementation(in directory: URL, withFileName filename: String? = nil) throws -> TagBackend? {
            if self == .none {
                return nil
            }
            var b: TagBackend? = nil

            if self == .plist {
                b = try FileTagBackend(withFileName: filename, forFilesIn: directory, writer: PropertyListFileWriter())
            }
            if self == .csv {
                b = try FileTagBackend(withFileName: filename, forFilesIn: directory, writer: CSVFileWriter())
            }
            if self == .xattr{
                b = XattrTagBackend()
            }
            if self == .json {
                b = try FileTagBackend(withFileName: filename, forFilesIn: directory, writer: JSONFileWriter())
            }
            if self == .ccts {
                b = try FileTagBackend(withFileName: filename, forFilesIn: directory, writer: CompressedCustomTagStoreWriter())
            }
            return b
        }
        
        case xattr, csv, plist, json, ccts
        case none
    }
    
    @State var formatChoice: Format = .none
    @State var lazyChoice: Bool = false
    @State var showingOptions: Bool = true
    @State var showingError: Bool = false
    @State var loadedFile: URL? = nil
    @State var directory: URL? = nil
    @State var backend: TagBackend? = nil
    @State var isImporting: Bool = false
    @State var isLoading: Bool = false
    @State var targeted: Bool = false
    @State var errorString: String = ""
    
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
                
            Group {
                Label("Choose a save format", systemImage: "2.circle")
                    .font(.title)
                
                Picker("", selection: $formatChoice, content: {
                    Text("CSV File").tag(Format.csv)
                        .help("Saves all tags of all files in a directory to a single CSV file also placed in that directory")
                    Text("Property List File").tag(Format.plist)
                        .help("Saves all tags of all files in a directory to a single (binary) Property List file also placed in that directory")
                    Text("JSON File").tag(Format.json)
                        .help("Saves all tags of all files in a directory to a single JSON file also placed in that directory")
                    Text("Custom Compressed Tag Store File").tag(Format.ccts)
                        .help("Saves all tags of all files in a directory to a single custom compressed binary format meant to make efficient use of space at the cost of compatibility with external editors")
                    Text("Extended File Attributes").tag(Format.xattr)
                        .help("Saves all tags of each files as extended attributes (xattr) of that file. The file retains its tags even when moved")
                })
                .pickerStyle(RadioGroupPickerStyle())
                .frame(minWidth: 200.0, maxWidth: 300.0)
                .padding()
                Toggle(isOn: $lazyChoice, label: {
                    Text("Lazy Writing?")
                })
            }
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
                        self.setBackend {
                            showingOptions = !$0
                        }
                    }
                } label: {
                    Label("Go!", systemImage: "arrowshape.forward")
                }.disabled(directory == nil || formatChoice == .none)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .padding()
        }
        .onDrop(of: ["public.file-url"], isTargeted: $targeted) { providers -> Bool in
            receiveDrop(providers: providers)
            return true
        }
        .frame(minWidth: 600.0, minHeight: 600.0, alignment: .center)
        .sheet(isPresented: $showingError, content: {
            VStack {
                Text("Invalid File Format").font(.title).padding()
                Text("The directory could not be opened. If make sure you have permission to access this directory")
                Text(errorString)
                HStack {
                    Button("Close") {
                        showingError = false
                    }
                    if let ext = formatChoice.fileExtension, let url = directory?.appendingPathComponent("\(FileTagBackend.filePrefix).\(ext)") {
                        Button("Delete File") {
                            // TODO: oh boy
                            try! FileManager.default.removeItem(at: url)
                            showingError = false
                            setBackend {
                                showingOptions = !$0
                            }
                        }
                    }
                }
            }.padding()
        })
    }
    
    
    
    var body: some View {
        if isLoading {
            ProgressView().progressViewStyle(CircularProgressViewStyle())
        } else if showingOptions {
            selectionView
                .fileImporter(
                            isPresented: $isImporting,
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
                        .onOpenURL(perform: { path in
                            isLoading = true
                            loadDroppedFile(path)
                            
                        })
        } else {
            MainView(choice: formatChoice, backend: backend!, directory: self.directory, showOptions: { showingOptions = true; formatChoice = .none; })
                
        }
        
    }
    
    func setBackend(onDone completed: @escaping (Bool) -> Void) {
        isLoading = true
        
        DispatchQueue.main.async {
            guard let dir = self.directory else { return completed(false) }
            let filename = loadedFile == nil ? nil : NSString(string: loadedFile!.lastPathComponent).deletingPathExtension
            
            do {
                backend = try formatChoice.implementation(in: dir, withFileName: filename)
                isLoading = false
                showingError = false
                completed(true)
            } catch FileWriterError.InvalidFileFormat {
                backend = nil
                isLoading = false
                errorString = "The file chosen has an invalid format."
                showingError = true
                completed(false)
            } catch FileWriterError.VersionMismatch {
                errorString = "The file chosen is from an old version of Graffiti and cannot be opened"
                showingError = true
                backend = nil
                isLoading = false
                completed(false)
            } catch {
                errorString = "An unknown error occurred"
                showingError = true
                backend = nil
                isLoading = false
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
                formatChoice = .xattr
                backend = XattrTagBackend()
            } else {
                loadedFile = url
                for format in Format.allCases {
                    if let f = format.fileExtension, url.pathExtension == f {
                        directory = url.deletingLastPathComponent()
                        formatChoice = format
                        self.setBackend { _ in
                            if backend != nil {
                                showingOptions = false
                                showingError = false
                            } else {
                                showingOptions = true
                                showingError = true
                            }
                        }
                        break
                    }
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

//
//  ContentView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 12/31/22.
//

import SwiftUI
import UniformTypeIdentifiers

extension URL {
    var absolutePath: String {
        absoluteString.replacingOccurrences(of: "file://", with: "")
    }
    
    var prettyPrinted: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return absolutePath.replacingOccurrences(of: home.absolutePath, with: "~/")
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
    enum Format: Hashable, CustomStringConvertible, CaseIterable {
        var description: String {
            switch self {
            case .plist: return "Property List"
            case .csv: return "Comma-Separated Values"
            case .xattr: return "Extended File Attributes"
            case .json: return "JSON File"
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
            }
        }
        
        func implementation(in directory: URL) -> (TagBackend?, Error?) {
            if self == .none {
                return (nil, nil)
            }
            var b: TagBackend?

            if self == .plist {
                b = FileTagBackend(forFilesIn: directory, writer: PropertyListFileWriter())
            }
            if self == .csv {
                b = FileTagBackend(forFilesIn: directory, writer: CSVFileWriter())
            }
            if self == .xattr{
                b = XattrTagBackend()
            }
            if self == .json {
                b = FileTagBackend(forFilesIn: directory, writer: JSONFileWriter())
            }

            if b == nil {
                return (nil, FileWriterError.InvalidFileFormat)
            }

            return (b, nil)
            
        }
        
        case xattr, csv, plist, json
        case none
    }
    
    @State var formatChoice: Format = .none
    @State var lazyChoice: Bool = false
    @State var showingOptions: Bool = true
    @State var showingInvalidFileFormat: Bool = false
    @State var loadedFile: URL? = nil
    @State var directory: URL? = nil
    @State var backend: TagBackend? = nil
    @State var isImporting: Bool = false
    @State var isLoading: Bool = false
    
    @State var targeted: Bool = false
    
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
        .sheet(isPresented: $showingInvalidFileFormat, content: {
            VStack {
                Text("Invalid File Format").font(.title).padding()
                Text("The directory could not be opened. If make sure you have permission to access this directory")
                if let ext = formatChoice.fileExtension {
                    Text("If there is a com-tom-graffiti.tagstore.\(ext) file in that directory, it is corrupt and must be deleted before opening the directory")
                }
                HStack {
                    Button("Close") {
                        showingInvalidFileFormat = false
                    }
                    if let ext = formatChoice.fileExtension, let url = directory?.appendingPathComponent("\(FileTagBackend.filePrefix).\(ext)") {
                        Button("Delete File") {
                            // TODO: oh boy
                            try! FileManager.default.removeItem(at: url)
                            showingInvalidFileFormat = false
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
        } else {
            MainView(choice: formatChoice, backend: backend!, directory: self.directory, showOptions: { showingOptions = true; formatChoice = .none; })
        }
        
    }
    
    func setBackend(onDone completed: @escaping (Bool) -> Void) {
        isLoading = true
        
        DispatchQueue.main.async {
            guard let dir = self.directory else { return completed(false) }
            let either = formatChoice.implementation(in: dir)
            print(either)
            
            switch(either) {
            case (nil, nil):
                backend = nil
                isLoading = false
                completed(false)
            case (let b, nil):
                backend = b
                isLoading = false
                completed(true)
            case (_, let error):
                showingInvalidFileFormat = true
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
                                showingInvalidFileFormat = false
                            } else {
                                showingOptions = true
                                showingInvalidFileFormat = true
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

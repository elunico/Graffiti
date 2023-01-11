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
        
        func implementation(in directory: URL) -> TagBackend? {
            switch self {
            case .plist: return FileTagBackend(forFilesIn: directory, writer: PropertyListFileWriter())
            case .csv: return FileTagBackend(forFilesIn: directory, writer: CSVFileWriter())
            case .xattr: return XattrTagBackend()
            case .json: return FileTagBackend(forFilesIn: directory, writer: JSONFileWriter())
            case .none: return nil
            }
        }
        
        case xattr, csv, plist, json
        case none
    }
    
    @State var formatChoice: Format = .xattr
    @State var lazyChoice: Bool = false
    @State var showingOptions: Bool = true
    @State var showingInvalidFileFormat: Bool = false
    @State var loadedFile: URL? = nil
    @State var directory: URL? = nil
    @State var backend: TagBackend? = nil
    
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
                    if directory != nil {
                        showingOptions = false
                    }
                } label: {
                    Label("Go!", systemImage: "arrowshape.forward")
                }.disabled(directory == nil)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .padding()
        }
        .onDrop(of: ["public.file-url"], isTargeted: $targeted) { providers -> Bool in
            
            providers.first?.loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { (data, error) in
                if let data = data, let path = String(data: data, encoding: .utf8), let url = URL(string: path) {
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.absolutePath, isDirectory: &isDir) && isDir.boolValue {
                        directory = url
                        loadedFile = nil
                        formatChoice = .xattr
                        showingOptions = false
                        backend = XattrTagBackend()
                    } else {
                        loadedFile = url
                        for format in Format.allCases {
                            if let f = format.fileExtension, url.pathExtension == f {
                                directory = url.deletingLastPathComponent()
                                formatChoice = format
                                backend = ({
                                    guard var b = formatChoice.implementation(in: self.directory!) else {
                                        return nil
                                    }
                                    if lazyChoice {
                                        b = LazyBackend(wrapping: b)
                                    }
                                    return b
                                })()
                                if backend != nil {
                                    showingOptions = false
                                    showingInvalidFileFormat = false
                                } else {
                                    showingOptions = true
                                    showingInvalidFileFormat = true
                                }
//                                showingOptions = false
                                break
                            }
                        }
                    }
                }
            })
            return true
        }
        .frame(minWidth: 600.0, minHeight: 600.0, alignment: .center)
        .sheet(isPresented: $showingInvalidFileFormat, content: {
            VStack {
                Text("Invalid File Format").font(.title).padding()
                if loadedFile != nil {
                    Text("The file provided at \(loadedFile?.absolutePath ?? "<nil>") is incorrectly formatted")
                    Text("The data may have been corrupted or the file might not be a Graffiti file")
                } else {
                    Text("The directory at \(directory?.absolutePath ?? "<nil>") could not be opened")
                    Text("Ensure that it exists and you have permission to access it")
                }
                Button("Close") {
                    showingInvalidFileFormat = false
                }
            }.padding()
                
        })
    }
    
    var body: some View {
        if showingOptions {
            selectionView
        } else {
//            assert(backend != nil)
            MainView(choice: formatChoice, backend: backend!, directory: self.directory, showOptions: { showingOptions = true })
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

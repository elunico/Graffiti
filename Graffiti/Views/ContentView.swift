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
    enum Format: Hashable, CustomStringConvertible {
        var description: String {
            switch self {
            case .plist: return "plist"
            case .csv: return "csv"
            case .xattr: return "xattr"
            case .none: return "<<none>>"
            }
        }
        
        case xattr, csv, plist
        case none
    }
    
    @State var formatChoice: Format = .xattr
    @State var lazyChoice: Bool = false
    @State var showingOptions: Bool = true
    @State var directory: URL? = nil
    
    var body: some View {
        if showingOptions {
            GeometryReader { geometry in
                VStack {
                    Group {
                        Text("Graffiti").font(.largeTitle)
                        Text("A File Tagging Application").font(.title2)
                    }
                    Spacer().frame(height: 50.0)
                    Group {
                        Group {
                            Button("Choose Directory") {
                                selectFolder {
                                    self.directory = $0[0]
                                }
                            }
                            Text("Selected: \(directory?.absolutePath ?? "<none>")")
                        }
                        Spacer().frame(height: 50.0)
                        Group {
                            Text("Choose a save format")
                                .font(.headline)
                            
                            Picker("", selection: $formatChoice, content: {
                                Text("CSV File").tag(Format.csv)
                                Text("plist File").tag(Format.plist)
                                Text("xattr attributes").tag(Format.xattr)
                            }).frame(minWidth: 200.0, maxWidth: 300.0)
                            Toggle(isOn: $lazyChoice, label: {
                                Text("Lazy Writing?")
                            })
                        }
                    }
                    Button("Go!") {
                        if directory != nil {
                            showingOptions = false
                        }
                    }.disabled(directory == nil)
//                    Spacer()
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .padding()
            }
        } else {
            
            let backend: TagBackend = ({
                var backend: TagBackend
                if formatChoice == .xattr {
                    backend = XattrTagBackend()
                } else if formatChoice == .csv {
                    backend = FileTagBackend(forFilesIn: self.directory!, writer: CSVFileWriter())
                } else if formatChoice == .plist {
                    backend = FileTagBackend(forFilesIn: self.directory!, writer: PropertyListFileWriter())
                } else {
                    fatalError()
                }
                
                if lazyChoice {
                    backend = LazyBackend(wrapping: backend)
                }
                return backend
            })()
            
            MainView(choice: formatChoice, backend: backend, directory: self.directory, showOptions: { showingOptions = true })
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

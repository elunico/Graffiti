//
//  ConvertView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/25/23.
//

import SwiftUI
import UniformTypeIdentifiers


struct ConvertView: View {
    @State var sourceFile: URL? = nil
    @State var beginFormat: Format = .none
    @State var endFormat: Format = .none
    
    @State var lazyChoice: Bool = false
    
    @State var showingError: Bool = false
    @State var showingSuccess: Bool = false
    @State var showingConfirmOverwrite: Bool = false
    
    @State var targeted: Bool = false
    @State var errorReason: String = ""
    
    func fail(reason: String) {
        errorReason = reason
        showingError = true
    }
    
    func performConversion(overwriting: Bool) {
        guard let sourceFile else { return }
        
        if let resultFile, !overwriting && FileManager.default.fileExists(atPath: resultFile) {
            showingConfirmOverwrite = true
            return
        }
        
        let currentWriter = try? getSandboxedAccess(to: sourceFile.deletingLastPathComponent().absolutePath, thenPerform: {
            try (beginFormat.implementation(in: URL(fileURLWithPath: $0)) as! FileTagBackend).writer
        })
        
        let nextWriter = try? getSandboxedAccess(to: sourceFile.deletingLastPathComponent().absolutePath, thenPerform: {
            try (endFormat.implementation(in: URL(fileURLWithPath: $0)) as! FileTagBackend).writer
        })
        
        if currentWriter == nil {
            return fail(reason: "Could not create interface to source file \(sourceFile.deletingLastPathComponent().absolutePath)")
        }
        
        if nextWriter == nil {
            return fail(reason: "Could not create interface to destination file")
        }
        
        if (try? convert(file: sourceFile, isUsing: currentWriter!, willUse: nextWriter!)) != nil {
            showingSuccess = true
        } else {
            fail(reason: "Could not perform conversion between \(sourceFile) and \(type(of: nextWriter!).writePath(in: sourceFile.deletingLastPathComponent(), named: nil))")
        }
    }
    
    var body: some View {
        VStack {
            Text("Convert between tag store formats").font(.title)
            Divider().frame(width: 100.0)
                .padding()
            
            Button("Choose a file") {
                let folderPicker = NSOpenPanel()
                let cases = Format.allCases.compactMap { $0.contentType }
                folderPicker.canChooseDirectories = false
                folderPicker.canChooseFiles = true
                folderPicker.allowedContentTypes = cases
                folderPicker.allowsMultipleSelection = false
                folderPicker.canDownloadUbiquitousContents = true
                folderPicker.canResolveUbiquitousConflicts = true
                
                folderPicker.begin { response in
                    if response == .OK {
                        sourceFile = folderPicker.url!
                        guard let beginFormat = Format.format(forExtension: sourceFile!.pathExtension) else { return }
                        self.beginFormat = beginFormat
                        
                    }
                }
            }
            Text("Converting: \(sourceFile?.absolutePath ?? "<none>")")
            
            Text("Starting format: \(beginFormat.fileExtension ?? "<unknown>")")
            
            VStack {
                Text("Convert To:").font(.title2)
                if sourceFile != nil {
                    FormatSelector(formatChoice: $endFormat)
                        .removing(formatOption: .xattr)
                        .removing(formatOption: Format.none)
                        .removing(formatOption: beginFormat)
                } else {
                    Text("Choose a file to begin")
                        .frame(height: 100.0)
                }
            }.padding()
            Button("Convert") {
                performConversion(overwriting: false)
                
            }
            
        }.padding()
            .frame(minWidth: 600, idealWidth: 600, minHeight: 400, idealHeight: 400)
            .sheet(isPresented: $showingError, content: {
                VStack {
                    Text("An Error occurred").font(.title)
                    Text(errorReason)
                    Button("Done") {
                        showingError = false
                    }
                }.padding()
            })
            .sheet(isPresented: $showingSuccess, content: {
                VStack {
                    Text("Done!").font(.title)
                    ({() -> Text in return Text("")})()
                    
                    Text("Successfully converted \n\(sourceFile?.absolutePath ?? "???") \nto \n\(resultFile ?? "???")")
                    Button("Done") {
                        showingSuccess = false
                    }
                }.padding()
            })
            .sheet(isPresented: $showingConfirmOverwrite, content: {
                VStack {
                    Text("Overwrite file?").font(.title)
                    Text("The file \(resultFile ?? "???") already exists")
                    Button("Cancel conversion") {
                        showingConfirmOverwrite = false
                    }
                    Button("Overwrite file") {
                        showingConfirmOverwrite = false
                        performConversion(overwriting: true)
                    }
                }.padding()
            })
            .onDrop(of: ["public.file-url"], isTargeted: $targeted) { providers -> Bool in
                providers.first?.loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { (data, error) in
                    if let data = data, let path = String(data: data, encoding: .utf8), let url = URL(string: path) {
                        sourceFile = url
                        guard let beginFormat = Format.format(forExtension: sourceFile!.pathExtension) else { return }
                        self.beginFormat = beginFormat
                    }
                })
                return true
            }
        
    }
    
    var resultFile: String? {
        sourceFile?.deletingPathExtension().appendingPathExtension(String(endFormat.fileExtension ?? "")).absolutePath
    }
}

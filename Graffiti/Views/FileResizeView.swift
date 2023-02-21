//
//  FileResizeView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/18/23.
//

import SwiftUI

struct FileResizeView: View {
    
    @State var sourceURL: URL? = nil
    @State var destinationURL: URL? = nil
    
    @State var destinationWidth: CGFloat? = nil
    @State var destinationHeight: CGFloat? = nil
    
    @State var overwriteOriginal: Bool = false
    @State var showingImageImportError: Bool = false
    
    @State var lockAspect: Bool = true
    
    @State var sourceWidth: CGFloat? = nil
    @State var sourceHeight: CGFloat? = nil
    
    func setSizes(_ url: URL?) {
        guard let url, let image = NSImage(contentsOf: url) else { return }
        sourceWidth = image.size.width
        sourceHeight = image.size.height
        destinationWidth = sourceWidth
        destinationHeight = sourceHeight
    }
    
    var body: some View {
        Group {
            HStack {
                
                VStack {
                    Text("Source").font(.title)
                    Text("Choose a source image")
                    Text("\(sourceURL?.absolutePath ?? "<none>")")
                    ImageSelector(selectedImage: $sourceURL, onClick: { existingImage in
                        DispatchQueue.main.async {
                            selectFile(ofTypes: [.image]) { urls in
                                guard let originalURL = urls.first else { return }
                                sourceURL = originalURL
                                setSizes(sourceURL)
                            }
                        }
                    }, onDroppedFile: { (url, providers) in
                        guard let provider = providers.first else { return false }
                        _ = provider.loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { data, error in
                            if let data, let s = String(data: data, encoding: .utf8), let originalURL = URL(string: s) {
                                if TagView.validImageExtensions.contains(originalURL.pathExtension.lowercased()) {
                                    sourceURL = originalURL
                                    setSizes(sourceURL)
                                } else {
                                    showingImageImportError = true
                                }
                                
                            }
                        })
                        
                        return true
                        
                    }).sheet(isPresented: $showingImageImportError, content: {
                        Text("Invalid image")
                        Text("The file \(sourceURL?.absolutePath ?? "<nil>") is not a valid image file")
                    })
                    
                    Toggle(isOn: $overwriteOriginal, label: {
                        Text("Overwrite original image?")
                    })
                }
                
                if !overwriteOriginal {
                    Divider().frame(width: 200)
                }
                
                VStack {
                    if !overwriteOriginal {
                        Text("Destination").font(.title)
                        Text("Choose a place to save")
                        Text(destinationURL?.absolutePath ?? "<none>")
                        Button("Choose") {
                            let s = NSSavePanel()
                            s.directoryURL = sourceURL?.deletingLastPathComponent()
                            let response = s.runModal()
                            
                            if response == .OK {
                                if let url = s.url {
                                    destinationURL = url
                                }
                            }
                        }
                    }
                }
                
                
            }
            Divider()
            Group {
                HStack {
                    Spacer()
                    Text("New Width:")
                    
                    TextField("Width", value: $destinationWidth, formatter: NumberFormatter())
                        .onChange(of: destinationWidth, perform: { _ in
                            guard let sourceWidth, let sourceHeight, let destinationWidth else { return }
                            if lockAspect {
                                var finalHeight = (sourceHeight / sourceWidth) * destinationWidth
                                destinationHeight = finalHeight
                            }
                        })
                    Spacer()
                }
                HStack {
                    Spacer()
                    Text("New Height: ")
                    TextField("Height", value: $destinationHeight, formatter: NumberFormatter())
                        .onChange(of: destinationHeight, perform: { _ in
                            guard let sourceWidth, let sourceHeight, let destinationHeight else { return }
                            if lockAspect {
                                var finalWidth = (sourceWidth / sourceHeight) * destinationHeight
                                destinationWidth = finalWidth
                            }
                        })
                    Spacer()
                }
                
                Toggle(isOn: $lockAspect, label: {
                    Text("Lock aspect ratio")
                })
            }
            
            Button("Resize!") {
                guard let sourceURL, let sourceWidth, let sourceHeight, let destinationWidth, let destinationHeight else { return }
                let newSize = resize(size: NSSize(width: sourceWidth, height: sourceHeight), toLongest: max(destinationWidth, destinationHeight))
                guard let oldImage = NSImage(contentsOf: sourceURL) else { return }
                resizeImage(source: oldImage, newSize: newSize) { newImage in
                    
                    let rep = NSBitmapImageRep(data: newImage.tiffRepresentation!)
                    let png = rep?.representation(using: .png, properties: [:])
                    try! png?.write(to: destinationURL ?? sourceURL)
                }
                
                
            }.disabled(
                sourceWidth == nil || sourceHeight == nil || sourceURL == nil || destinationHeight == nil || destinationWidth == nil
            )
        }
            .frame(width: 600, height: 600, alignment: .center)
            .padding()
    }
}

struct FileResizeView_Previews: PreviewProvider {
    static var previews: some View {
        FileResizeView()
    }
}

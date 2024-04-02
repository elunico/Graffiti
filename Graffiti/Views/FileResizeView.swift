//
//  FileResizeView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/18/23.
//

import SwiftUI

extension CGFloat {
    func coercing(_ values: Array<CGFloat>, to newValue: CGFloat, threshold: Double = 0.05) -> CGFloat {
        if values.anySatisfy({ value in value == self || (abs(self - value) < threshold) || (isNaN && value.isNaN) }) {
            return newValue
        }
        return self
    }
}

extension Optional: CustomStringConvertible where Wrapped: CustomStringConvertible {
    public var description: String {
        switch self {
        case .none:
            return "Optional<\(Wrapped.self)>(nil)"
        case .some(let wrapped):
            return "Optional<\(Wrapped.self) [\(type(of: wrapped))]>(\(wrapped))"
        }
    }
}

extension String.StringInterpolation {
    mutating func appendInterpolation<W>(_ o: Optional<W>) where W: CustomStringConvertible {
        appendLiteral(o.description)
    }
}

class CGFloatFormatter: NumberFormatter {
    
    override func number(from string: String) -> NSNumber? {
        if let value = Int(string) {
            return value as NSNumber
        }
        
        guard let r = super.number(from: string) else { return 0 }
        if r == 0 || r.doubleValue.isNaN || r.doubleValue.isInfinite {
            return 0
        } else {
            print("Number \(r)")
            return r
        }
    }
    
    override func string(from number: NSNumber) -> String? {
        let value = super.string(from: number)
        if value == nil || value?.isEmpty == true {
            return "0"
        }
        print("String \(value)")
        return value
    }
    
    override var zeroSymbol: String? {
        get { "0" }
        set { talk("Discarding set of \(newValue)") }
    }
    override var nilSymbol: String {
        get { "0" }
        set { talk("Discarding set of \(newValue)") }
    }
    override var positiveInfinitySymbol: String {
        get { "0" }
        set { talk("Discarding set of \(newValue)") }
    }
    override var notANumberSymbol: String? {
        get { "0" }
        set { talk("Discarding set of \(newValue)") }
    }
    override var negativeInfinitySymbol: String {
        get { "0" }
        set { talk("Discarding set of \(newValue)") }
    }
}

fileprivate func talk(_ message: String) {
    if false {
        print(message)
    }
}

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
    
    @State var loading: Bool = false
    @State var success: Bool = false
    @State var done: Bool = false
    
    func setSizes(_ url: URL?) {
        guard let url, let image = NSImage(contentsOf: url) else { return }
        sourceWidth = image.size.width
        sourceHeight = image.size.height
        destinationWidth = sourceWidth
        destinationHeight = sourceHeight
    }
    
    var body: some View {
        if loading {
            ProgressView().progressViewStyle(CircularProgressViewStyle())
        } else {
            Group {
                GeometryReader { reader in
                    
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
                        }.frame(width: reader.size.width / 2, alignment: .center)
                        
                        Divider()
                        
                        VStack {
                            Text("Destination").font(.title)
                            if !overwriteOriginal {
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
                            } else {
                                Text("Overwriting original!").font(.body.bold()).foregroundColor(.red)
                            }
                        }.frame(width: reader.size.width / 2, alignment: .center)
                        
                    }.frame(alignment: .center)
                        .padding(.all, 2.0)
                }
            }
            
            Divider()
            Group {
                
                Button("Reset Dimensions") {
                    destinationHeight = sourceHeight
                    destinationWidth = sourceWidth
                }
                
                HStack {
                    Text("New Width:")
                    
                    
                    TextField("Width", value: $destinationWidth, formatter: CGFloatFormatter())
                        .onChange(of: destinationWidth, perform: { _ in
                            guard let sourceWidth, let sourceHeight, let destinationWidth else { return }
                            if lockAspect {
                                let finalHeight = (sourceHeight / sourceWidth).coercing([.infinity, .nan, .zero], to: 1, threshold: 1.0) * destinationWidth
                                destinationHeight = finalHeight
                            }
                            
                        })
                }.padding(.horizontal, 5.0)
                HStack {
                    Text("New Height: ")
                    TextField("Height", value: $destinationHeight, formatter: CGFloatFormatter())
                        .onChange(of: destinationHeight, perform: { _ in
                            guard let sourceWidth, let sourceHeight, let destinationHeight else { return }
                            if lockAspect {
                                let finalWidth = (sourceWidth / sourceHeight).coercing([.infinity, .nan, .zero], to: 1, threshold: 1.0) * destinationHeight
                                destinationWidth = finalWidth
                            }
                        })
                }
                .padding(.horizontal, 5.0)
                
                Toggle(isOn: $lockAspect, label: {
                    Text("Lock aspect ratio")
                }).onChange(of: lockAspect, perform: {
                    if ($0) {
                        guard let sourceWidth, let sourceHeight, let destinationWidth else { return }
                        let finalHeight = (sourceHeight / sourceWidth).coercing([CGFloat.infinity, CGFloat.nan], to: 0) * destinationWidth
                        destinationHeight = finalHeight
                    }
                })
            }
            .padding(.all, 2.0)
            
            Button("Resize!") {
                guard let sourceURL, let sourceWidth, let sourceHeight, let destinationWidth, let destinationHeight else { return }
                loading = true
                let newSize = resize(size: NSSize(width: sourceWidth, height: sourceHeight), toLongest: max(destinationWidth, destinationHeight))
                guard let oldImage = NSImage(contentsOf: sourceURL) else { return }
                resizeImage(source: oldImage, newSize: newSize) { newImage in
                    let rep = NSBitmapImageRep(data: newImage.tiffRepresentation!)
                    let png = rep?.representation(using: .png, properties: [:])
                    success = (try? png?.write(to: destinationURL ?? sourceURL)) != nil
                    loading = false
                    done = true
                }
            }
            .padding(10)
            .disabled(
                sourceWidth == nil || sourceHeight == nil || sourceURL == nil || destinationHeight == nil || destinationWidth == nil
            )
            
            
            .sheet(isPresented: $done) {
                if success {
                    VStack {
                        Text("Done!").font(.title)
                        Text("Successfully converted image")
                        Button("Close") {
                            done = false
                        }
                    }.padding()
                } else {
                    VStack {
                        Text("Error").font(.title)
                        Text("Could not convert the image")
                        Button("Close") {
                            done = false
                        }
                    }.padding()
                }
            }
        }
    }
}


struct FileResizeView_Previews: PreviewProvider {
    static var previews: some View {
        FileResizeView()
    }
}

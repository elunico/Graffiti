//
//  ImageSelector.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/9/23.
//

import SwiftUI

fileprivate var thumbnailCache : NSCache<NSURL, NSImage> = NSCache(countLimit: 50)

struct ImageSelector: View {
    
    public static let size = CGSize(width: 250, height: 100)
    public static let hoverScale = 1.08
    
    private var w: Double { Double(ImageSelector.size.width) }
    private var h: Double { Double(ImageSelector.size.height) }
    private var min: Double { Double(Swift.min(ImageSelector.size.width, ImageSelector.size.height))}
    
    @Binding var selectedImage: URL?
    
    @State private var isDroppingImage = false
    @State private var imageHovering = false
    @State var onClick: (_ existingImage: URL?) -> ()
    @State var onDroppedFile: (_ existingImage: URL?, _ providers: [NSItemProvider]) -> Bool
    @State var scaleFactor: Double = 1.0
    
    var body: some View {
        if selectedImage == nil {
            ZStack {
                Image(systemName: "plus.square")
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(CGSize(width: 0.5, height: 0.5))
                    .frame(idealWidth: min, maxWidth: min, idealHeight: min, maxHeight: min, alignment: .center)
                    .offset(x: 0, y: 0)
                    .onHover(perform: {
                        scaleFactor = $0 ? ImageSelector.hoverScale : 1
                    })
                    .zIndex(2)
                    .shadow(color: .gray, radius: 25.0)

                
//                RoundedRectangle(cornerRadius: 18.0)
//                    .padding()
//                    .frame(idealWidth: min, maxWidth: min, idealHeight: min, maxHeight: min)
//                    .foregroundColor(Color(.systemGray))
//                    .offset(x: 0, y: 0)
//                    .shadow(radius: 10)
//                    .onHover(perform: {
//                        scaleFactor = $0 ? ImageSelector.hoverScale : 1
//                    })
            }
            .scaleEffect(x: scaleFactor, y: scaleFactor)
            .animation(.easeInOut(duration: 0.1), value: scaleFactor)
            .onHover(perform: {
                scaleFactor = $0 ? ImageSelector.hoverScale : 1
            })
            .frame(idealWidth: w, maxWidth: w, idealHeight: h, maxHeight: h, alignment: .center)
            
            .onDrop(of: ["public.file-url"], isTargeted: $isDroppingImage, perform: { providers in
                return onDroppedFile(selectedImage, providers)
            }).onTapGesture {
                onClick(selectedImage)
            }
        } else {
            ZStack(alignment: .topLeading) {
                ImageSelector.imageOfFile(selectedImage!)
                    .resizable()
                    .scaledToFit()
                    .frame(width: w, height: h)
                    .onDrop(of: ["public.file-url"], isTargeted: $isDroppingImage, perform: { providers in
                        onDroppedFile(selectedImage, providers)
                    })
                    .offset(x: 0, y: 0)
                if imageHovering {
                    Image(systemName: "x.square")
                        .background(in: Rectangle(), fillStyle: FillStyle())
                        .foregroundColor(.primary)
                        .font(.system(size: 18.0))
                        .onTapGesture {
                            selectedImage = nil
                        }
                        .offset(x: 0, y: 0)
                }
            }.onHover {
                imageHovering = $0
            }.frame(idealWidth: w, maxWidth: w, idealHeight: h, maxHeight: h, alignment: .center)
        }
    }
    
    static func imageOfFile(_ url: URL?) -> Image {
        
        if let url {
//            return Image(nsImage: NSImage(byReferencing: url))
            if let image = thumbnailCache.object(forKey: url as NSURL) {
                return Image(nsImage: image)
            } else {
                let nsImage = NSImage(byReferencing: url)
                thumbnailCache.setObject(nsImage, forKey: url as NSURL)
                return Image(nsImage: nsImage)
            }
        } else {
            return Image(systemName: "exclamationmark.triangle")
        }
        
    }
}

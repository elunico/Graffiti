//
//  ImageSelector.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/9/23.
//

import SwiftUI

struct ImageSelector: View {
    
    @Binding var selectedImage: URL?
    
    @State private var isDroppingImage = false
    @State private var imageHovering = false
    @State var onClick: (_ existingImage: URL?) -> ()
    @State var onDroppedFile: (_ existingImage: URL?, _ providers: [NSItemProvider]) -> Bool
    
    var body: some View {
        if selectedImage == nil {
            ZStack {
                Image(systemName: "plus.square")
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(CGSize(width: 0.5, height: 0.5))
                    .frame(width: 200, height: 150, alignment: .center)
                    .offset(x: 0, y: 0)
                    .zIndex(2)
                
                RoundedRectangle(cornerRadius: 18.0)
                    .padding()
                    .frame(width: 200, height: 150)
                    .foregroundColor(Color(.systemGray))
                    .offset(x: 0, y: 0)
            }
            .frame(width: 200, height: 150, alignment: .center)
            
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
                    .frame(width: 200, height: 150)
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
            }
        }
    }
    
    static func imageOfFile(_ url: URL) -> Image {
        if FileManager.default.fileExists(atPath: url.absolutePath) {
            return Image(nsImage:  NSImage(byReferencing: url))
        } else {
            return Image(systemName: "exclamationmark.triangle")
        }
        
    }
}

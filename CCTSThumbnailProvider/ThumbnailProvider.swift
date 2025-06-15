//
//  ThumbnailProvider.swift
//  CCTSThumbnailProvider
//
//  Created by Thomas Povinelli on 1/22/23.
//

import QuickLookThumbnailing
import AppKit

class ThumbnailProvider: QLThumbnailProvider {
    
    var extensionBadge: String {
        "ccts"
    }
    
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let contextSize = request.maximumSize
        guard let image = NSImage(systemSymbolName: "doc", accessibilityDescription: "") else { return }
        guard let tagImage = NSImage(systemSymbolName: "tag", accessibilityDescription: "") else { return }
               
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        
        let topY = (contextSize.height / 2 + (contextSize.height / 6)) - 10
        let botY = (contextSize.height / 2 - (contextSize.height / 6)) - 10
        let font =  NSFont.systemFont(ofSize: max(contextSize.height / 9, 10))
        
        image.size.height = contextSize.height / 4
        image.size.width = contextSize.height / 4
        tagImage.size.height = contextSize.height / 4
        tagImage.size.width = contextSize.height / 4
        
        if let store = try? CompressedCustomTagStoreWriter().loadFrom(path: request.fileURL.absolutePath) {
            print("First one")
            let fileCount = store.tagData.count.description
            let tagCount = store.tagData.map { (key, value) in value.count }.reduce(0, +).description
            
            // First way: Draw the thumbnail into the current context, set up with UIKit's coordinate system.
            handler(QLThumbnailReply(contextSize: request.maximumSize, currentContextDrawing: { () -> Bool in
                image.draw(in: CGRect(x: 5, y: topY, width: tagImage.size.width, height: tagImage.size.height))
                NSAttributedString(string: "\(fileCount)", attributes: [.paragraphStyle: paragraph, .font: font]).draw(in: CGRect(x: 20, y: topY - 2, width: contextSize.width - 25, height: contextSize.height / 4))
                
                tagImage.draw(in: CGRect(x: 5, y: botY, width: image.size.width, height: image.size.height))
                NSAttributedString(string: "\(tagCount)", attributes: [.paragraphStyle: paragraph, .font: font]).draw(in: CGRect(x: 20, y: botY - 2, width: contextSize.width - 25, height: contextSize.height / 4))
                
                // Return true if the thumbnail was successfully drawn inside this block.
                return true
            }), nil)
        } else {
            handler(QLThumbnailReply(contextSize: request.maximumSize, currentContextDrawing: { () -> Bool in
                image.draw(in: CGRect(x: 5, y: topY, width: tagImage.size.width, height: tagImage.size.height))
                NSAttributedString(string: "Could not load thumbnail", attributes: [.paragraphStyle: paragraph, .font: font]).draw(in: CGRect(x: 20, y: topY - 2, width: contextSize.width - 25, height: contextSize.height / 4))
                
                // Return true if the thumbnail was successfully drawn inside this block.
                return true
            }), nil)
        }
        
    }
}

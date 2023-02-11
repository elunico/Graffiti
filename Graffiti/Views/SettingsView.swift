//
//  SettingsView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/7/23.
//

import SwiftUI

extension View {
    func wrapText() -> some View {
        self.frame(
            minWidth: 0,
            maxWidth: .infinity,
            minHeight: 0,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: ApplicationState
    
    static let copyOwnedImagesDefaultsKey = "com.tom.graffiti-copyOwnedImages"
    static let saveImageURLsDefaultsKey = "com.tom.graffiti-saveImageURLs"
    static let doTextRecognition = "com.tom.graffiti-doTextRecognition"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10.0) {
            Group {
                
                Text("File Control").font(.headline)
//                Toggle("Copy images that are used to tag files", isOn: $appState.copyOwnedImages)
//                    .onChange(of: appState.copyOwnedImages, perform: {
//                        UserDefaults.thisAppDomain?.set($0, forKey: SettingsView.copyOwnedImagesDefaultsKey)
//                    })
//                Text("If you choose NOT to copy images, you must grant Graffiti full disk access in System Settings or you will not be able to see your images in the app")
//                    .wrapText()
//                    .font(.caption2)
//                    .offset(x: 10)
                
                Text("Format for Saving Images")
                Picker("", selection: $appState.imageSaveFormat, content: {
                    Text("Save References to files locally stored on the computer (faster; less space)").tag(Tag.ImageFormat.url)
                    Text("Save Image Content to Tag Store file directly (portable; larger files)").tag(Tag.ImageFormat.content)
                }).onChange(of: appState.imageSaveFormat, perform: {
                    UserDefaults.thisAppDomain?.set($0 == .url, forKey: SettingsView.saveImageURLsDefaultsKey)
                })
            }
            Divider()
            Group {
                Text("Application Behavior").font(.headline)
                Toggle("Recognize Text in Images", isOn: $appState.doImageVision)
                    .onChange(of: appState.doImageVision, perform: {
                        UserDefaults.thisAppDomain?.set($0, forKey: SettingsView.doTextRecognition)
                    })
            }
            
        }.padding()
            .onAppear {
//                appState.copyOwnedImages = UserDefaults.thisAppDomain?.bool(forKey: SettingsView.copyOwnedImagesDefaultsKey) ?? true
                appState.imageSaveFormat = UserDefaults.thisAppDomain?.bool(forKey: SettingsView.saveImageURLsDefaultsKey) ?? true  ? Tag.ImageFormat.url : Tag.ImageFormat.content
                appState.doImageVision = UserDefaults.thisAppDomain?.bool(forKey: SettingsView.doTextRecognition) ?? true
                
            }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

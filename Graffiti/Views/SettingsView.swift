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
    @EnvironmentObject var taggedDirectory: TaggedDirectory
    
    static let copyOwnedImagesDefaultsKey = "com.tom.graffiti-copyOwnedImages"
    static let saveImageURLsDefaultsKey = "com.tom.graffiti-saveImageURLs"
    static let doTextRecognition = "com.tom.graffiti-doTextRecognition"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10.0) {
            Group {
                
                Text("File Control").font(.headline)
                Section {
                    Text("Change image save format of all tags")
                    Text("Save Tag Images as")
                    Picker("", selection: $appState.imageSaveFormat, content: {
                        Text("Links to local image files (faster; less space)").tag(Tag.ImageFormat.url)
                        Text("Inline full image data (portable; larger files)").tag(Tag.ImageFormat.content)
                    }).disabled(!AppState.tagChangeableStates.contains(appState.currentState))
                    Button("Change All Tags") {
                        taggedDirectory.convertTagStorage(to: appState.imageSaveFormat)
                        UserDefaults.thisAppDomain?.set(appState.imageSaveFormat == .url, forKey: SettingsView.saveImageURLsDefaultsKey)
                    }.disabled(!AppState.tagChangeableStates.contains(appState.currentState))
                }
                Button("Clear Thumbnail Cache") {
                    try? pruneThumbnailCache()
                }
            }
            Divider()
            Group {
                Text("Application Behavior").font(.headline)
                Toggle("Recognize Text in Images", isOn: $appState.doImageVision)
                    .onChange(of: appState.doImageVision, perform: {
                        UserDefaults.thisAppDomain?.set($0, forKey: SettingsView.doTextRecognition)
                    }).disabled(!AppState.tagChangeableStates.contains(appState.currentState))
            }
            
            
        }.padding()
            .onAppear {
                loadDefaultSettings(to: appState)
                
            }
    }
}

func loadDefaultSettings(to appState: ApplicationState) {
    appState.imageSaveFormat = (UserDefaults.thisAppDomain?.bool(forKey: SettingsView.saveImageURLsDefaultsKey) ?? true)  ? Tag.ImageFormat.url : Tag.ImageFormat.content
    appState.doImageVision = UserDefaults.thisAppDomain?.bool(forKey: SettingsView.doTextRecognition) ?? true
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

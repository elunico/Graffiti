//
//  SettingsView.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/7/23.
//

import SwiftUI


struct SettingsView: View {
    @EnvironmentObject var appState: ApplicationState
    @EnvironmentObject var taggedDirectory: TaggedDirectory
    
    static let copyOwnedImagesDefaultsKey = "com.tom.graffiti-copyOwnedImages"
    static let saveImageURLsDefaultsKey = "com.tom.graffiti-saveImageURLs"
    static let doTextRecognition = "com.tom.graffiti-doTextRecognition"
    static let showSpotlightKinds = "com.tom.graffiti-showSpotlightKinds"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10.0) {
            Group {
                
                Text("File Control").font(.headline)
                Section {
                    Text("Change image save format of all tags")
                    Picker("", selection: $appState.imageSaveFormat, content: {
                        Text("Save Images as Links to local image files (faster; less space)").tag(Tag.ImageFormat.url)
                        Text("Save Images as Inline full image data (portable; larger files)").tag(Tag.ImageFormat.content)
                    }).disabled(!AppState.tagChangeableStates.contains(appState.currentState))
                    Button("Change All Tags") {
                        taggedDirectory.convertTagStorage(to: appState.imageSaveFormat)
                        UserDefaults.thisAppDomain?.set(appState.imageSaveFormat == .url, forKey: SettingsView.saveImageURLsDefaultsKey)
                    }.disabled(!AppState.tagChangeableStates.contains(appState.currentState))
                }
                Divider()
                Text("Image Thumbnail Cache").font(.subheadline)
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
                Divider()
                Toggle("Show Spotlight File Kinds", isOn: $appState.showSpotlightKinds)
                    .onChange(of: appState.showSpotlightKinds, perform: {
                        UserDefaults.thisAppDomain?.set($0, forKey: SettingsView.showSpotlightKinds)
                    })
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
    appState.showSpotlightKinds = UserDefaults.thisAppDomain?.bool(forKey: SettingsView.showSpotlightKinds) ?? false
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

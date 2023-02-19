//
//  ApplicationState.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/28/23.
//

import Cocoa

enum AppState : Equatable, Hashable {
    case StartScreen
    case Converting
    case Loading
    case MainView(hasSelection: Bool)
    case EditingTags
    case ShowingFileError
    case EditingFileView
    case ShowingConfirm
    
    static var tagChangeableStates: Set<AppState> {
        var states = Set<AppState>()
        states.insert(AppState.MainView(hasSelection: true))
        states.insert(AppState.MainView(hasSelection: false))
        states.insert(AppState.EditingTags)
        states.insert(AppState.EditingFileView)
        return states
    }
}

class AnySelectionModel: ObservableObject {
    @Published var selectedItems: [Any] = []
    var isSingleSelected: Bool = false
}


class ApplicationState: ObservableObject {
    
    @Published var currentState: AppState = .StartScreen
    
    @Published var isImporting: Bool = false
    @Published var isConverting: Bool = false
    @Published var isLoading: Bool = false {
        didSet {
            if !isLoading {
                NSApplication.shared.requestUserAttention(.informationalRequest)
            }
        }
    }
    
    @Published var editing: Bool = false
    @Published var isPresentingConfirm: Bool = false
    @Published var showingMoreInfo: Bool = false
    @Published var showingOptions = true 
    
    @Published var showingHelp = false
    
    @Published var selectionModels: [AnySelectionModel] = []
    
//    @Published var copyOwnedImages: Bool = true
    @Published var doImageVision: Bool = true
    @Published var imageSaveFormat: Tag.ImageFormat = .url
    
    @Published var showingImageImportError: Bool = false 
    
    func reset() {
        currentState = .StartScreen
        isImporting = false
        isConverting = false
        isLoading = false
        editing = false
        isPresentingConfirm = false
        showingMoreInfo = false
        showingOptions = true
        showingHelp = false
        selectionModels = []
    }
    
    
    func select(only object: Any) {
        clearSelection()
        select(additionalItem: object)
        objectWillChange.send()
    }
    
    func select(additionalItem item: Any) {
        selectionModels.last?.selectedItems.append(item)
        objectWillChange.send()
    }
    
    func select(only objects: any Sequence) {
        clearSelection()
        for item in objects {
            select(additionalItem: item)
        }
        objectWillChange.send()
    }
    
    func clearSelection() {
        selectionModels.last?.selectedItems.removeAll()
        objectWillChange.send()
    }
    
    @discardableResult
    func createSelectionModel() -> AnySelectionModel {
        let model = AnySelectionModel()
        selectionModels.append(model)
        return model
    }
    
    @discardableResult
    func releaseSelectionModel() -> AnySelectionModel? {
        selectionModels.popLast()
    }
    
    //    @Published var showingError: Bool = false
    //    @Published var showingSuccess: Bool = false
    //    @Published var showingConfirmOverwrite: Bool = false
    
}

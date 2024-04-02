//
//  TaggedDirectory.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/2/23.
//

import Foundation
import Vision
import AppKit
import CoreML
import CoreImage

enum LoadResult: Error {
    case ExistingAutosave
}

class TaggedDirectory: ObservableObject {
    enum TaggedState {
        case all, tagged, untagged
    }
    
    static let empty: TaggedDirectory = TaggedDirectory()
    private static let alwaysTrue: (TaggedFile) -> Bool = { _ in true }
    
    @Published var directory: String
    @Published var files: [TaggedFile] = []
    private var backend: TagBackend?
    private var indexMap: [TaggedFile.ID: Int] = [:]
    
    private var filterPredicate: (TaggedFile) -> Bool = alwaysTrue
    private var query: String = ""
    
    @Published private(set) var transactions: [TagTransaction] = []
    @Published private(set) var redoStack: [TagTransaction] = []
    
    private var queue = DispatchQueue(label: "imageProcessor", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .workItem, target: DispatchQueue.global(qos: .userInitiated))

    @Published var doImageVision: Bool = true {
        didSet {
            if doImageVision {
                performVisionActions()
            } else {
                files.forEach { file in
                    backend?.removeTagText(from: file)
                    file.tags.forEach { tag in tag.recoginitionState = .uninitialized }
                }
            }
        }
    }
    
    func didMutate() {
        print("Performing autosave commmit")
        self.temporaryAutosaveCommit()
    }
    
    func reset() {
        directory = ""
        files = []
        indexMap = [:]
        
        filterPredicate = TaggedDirectory.alwaysTrue
        query = ""
        
        transactions = []
        redoStack = []
    }
    
    private init() {
        self.directory = ""
        self.backend = nil
    }
    
    func sort(with sorter: Sorter?) {
        guard let sorter else { return }
        self.files.sort(using: sorter)
        objectWillChange.send()
    }
    

    func loadAutosave(directory: String, filename: String? = nil, format: Format, doTextRecognition: Bool = true, ignoreAutosave: Bool = false)  throws {
        backend.restoreFromAutosave(suffixedWith: ".tmpstore")
    }
    
    
    func load(directory: String, filename: String? = nil, format: Format, doTextRecognition: Bool = true, ignoreAutosave: Bool = false)  throws {
//        print("In directory filename is \(filename)")
        self.indexMap.removeAll()
        self.files.removeAll()
        self.directory = directory
        self.doImageVision = doTextRecognition
        guard let backend = try format.implementation(in: URL(fileURLWithPath: directory), withFileName: filename) else { return }
        self.backend = backend
        if !ignoreAutosave && backend.hasTemporaryAutosave(suffixedWith: ".tmpstore") {
            throw LoadResult.ExistingAutosave
        }
        backend.removeTemporaryAutosave(suffix: ".tmpstore")
        let content = try  getContentsOfDirectory(atPath: directory)
        var idx = 0
        for file in content {
            let tf = TaggedFile(parent: directory, filename: file, backend: backend)
            files.append(tf)
            indexMap[tf.id] = idx
            idx += 1
        }
        if doTextRecognition {
            performVisionActions()
        }
    }
    
    func getFile(withID id: String) -> TaggedFile? {
        guard let index = indexMap[id] else { return nil }
        return files[index]
    }
    
    func getFiles(withIDs ids: Set<String>) -> Set<TaggedFile> {
        return Set(ids.map { indexMap[$0] }.filter { $0 != nil }.map { files[$0!] })
    }
    
    var tagStore: String? {
        (backend as? FileTagBackend)?.saveFile
    }
    
    func addTags(_ tag: Tag, toAll files: [TaggedFile]) {
//        print("adding tags method")
        if let backend {
            transactions.append(AddTagToManyFilesTransaction(backend: backend, tag: tag, files: files))
        }
        transactions.last?.perform()
        invalidateRedo()
        performVisionActions()
        didMutate()
    }
    
    func addTag(_ tag: Tag, to file: TaggedFile) {
        if let backend {
            transactions.append(AddTagTransaction(backend: backend, tag: tag, file: file))
        }
        transactions.last?.perform()
        invalidateRedo()
        performVisionActions()
        didMutate()
    }
    
    func removeTag(withString string: String, from file: TaggedFile) {
        let tag = Tag.tag(withString: string)
        if let backend {
            transactions.append(RemoveTagTransaction(backend: backend, tag: tag, file: file))
        }
        transactions.last?.perform()
        invalidateRedo()
        didMutate()
    }
    
    func removeTag(withID id: Tag.ID, from file: TaggedFile) {
        guard let tag = Tag.tag(fromID: id) else { return }
        if let backend {
            transactions.append(RemoveTagTransaction(backend: backend, tag: tag, file: file))
        }
        transactions.last?.perform()
        invalidateRedo()
        didMutate()
    }
    
    
    func removeTag(withID id: Tag.ID, fromAll files: [TaggedFile]) {
        guard let tag = Tag.tag(fromID: id) else { return }
        if let backend {
            transactions.append(RemoveTagFromManyFilesTransaction(backend: backend, tag: tag, files: files))
        }
        transactions.last?.perform()
        invalidateRedo()
        didMutate()
    }
    
    func invalidateRedo() {
        redoStack.removeAll()
    }
    
    func invalidateUndo() {
        transactions.removeAll()
    }
    
    func undo() {
        guard let t = transactions.popLast() else { print("Nothing to undo"); return }
        t.undo()
        redoStack.append(t)
        didMutate()
    }
    
    func redo() {
        guard let t = redoStack.popLast() else { print("Nothing to redo"); return }
        t.redo()
        transactions.append(t)
        didMutate()
    }
    
    func loadTags(at path: String) -> Set<Tag> {
        let t = backend?.loadTags(at: path) ?? []
        invalidateUndo()
        didMutate()
        return t
    }
    
    func clearTags(of file: TaggedFile) {
        file.tags.forEach { $0.relieve() }
        backend?.clearTags(of: file)
        invalidateUndo()
        invalidateRedo()
        didMutate()
    }
    
    func temporaryAutosaveCommit() {
        backend?.temporaryAutosaveCommit(files: self.files, suffix: ".tmpstore")
    }
    
    func persist() {
        backend?.commit(files: files, force: true)
    }
    
    func commit() {
        commit(files: self.files)
    }
    
    func commit(files: [TaggedFile]) {
        persist()
        self.indexMap.removeAll()
        self.files.removeAll(keepingCapacity: true)
        invalidateUndo()
        invalidateRedo()
        print("Removing autosave temporary file")
        backend?.removeTemporaryAutosave(suffix: ".tmpstore")
    }
    
    /// special characters used by the Tag backend that are
    /// prohibited from being used in Tags themselves
    var implementationProhibitedCharacters: Set<Character> { backend?.implementationProhibitedCharacters ?? [] }


    var prohibitedCharacters: Set<Character> {
        backend?.prohibitedCharacters ?? []
    }
    
    func convertTagStorage(to format: Tag.ImageFormat) {
        for file in files {
            for tag in file.tags {
                tag.imageFormat = format
//                print(tag.imageFormat)
            }
        }
        persist()
    }

}

// Functions for filtering
extension TaggedDirectory {

    func filter(by query: String, within state: TaggedState = .all) -> [TaggedFile] {
        self.query = query
        if query.isEmpty {
            filterPredicate = TaggedDirectory.alwaysTrue
        } else {
            let results = query.split(separator: "|").map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }.map{ $0.split(separator: "&").map{ s in s.trimmingCharacters(in: .whitespacesAndNewlines)} }
            filterPredicate = {
                file in results.anySatisfy {
                    conjunction in conjunction.allSatisfy {
                        text in
                        let substr = text[text.index(after: text.startIndex)...]
                        return (text.hasPrefix("!") && !file.searchableMetadataString.localizedCaseInsensitiveContains(substr) && !file.filename.localizedCaseInsensitiveContains(substr)) || (!text.hasPrefix("!") && ((file.searchableMetadataString.localizedCaseInsensitiveContains(text) || file.filename.localizedCaseInsensitiveContains(text))))
                    }
                }
            }
        }
        switch state {
        case .all:
            return files.filter(filterPredicate)
        case .untagged:
            return files.filter { $0.tags.count == 0 && filterPredicate($0) }
        case .tagged:
            return files.filter { $0.tags.count > 0 && filterPredicate($0) }
        }
    }
}

extension TaggedDirectory {
    func recognizeObjects(in tag: Tag) {
        guard let model = try? VNCoreMLModel(for: MobileNetV2(configuration: MLModelConfiguration()).model) else { return }
        
        let request = VNCoreMLRequest(model: model)
        
        guard let url = tag.image, let nsImage = NSImage(contentsOf: url), let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        let handler = VNImageRequestHandler(ciImage: CIImage(cgImage: cgImage), options: [:])
        
        try? handler.perform([request])
        
        guard let results = request.results as? [VNClassificationObservation] else {
            return
        }
        
        let observations = results[0..<5].filter{ (!$0.hasPrecisionRecallCurve) || ($0.hasPrecisionRecallCurve && $0.hasMinimumPrecision(0.8, forRecall: 0.8)) }.map { $0.identifier }
        
        
        tag.imageTextContent.append(contentsOf: observations)
        
    }
    
    func recognizeText(in tag: Tag) {
        
        guard let imageURL = tag.image else { return }
        
        guard let cgImage = NSImage(byReferencing: imageURL).cgImage(forProposedRect: nil, context: nil , hints: nil) else { return }
        
        // Create a new image-request handler.
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        
        // Create a new request to recognize text.
        let request = VNRecognizeTextRequest(completionHandler: {(request: VNRequest, error: Error?) in
            guard let observations =
                    request.results as? [VNRecognizedTextObservation] else {
                return
            }
            let recognizedStrings = observations.compactMap { observation in
                // Return the string of the top VNRecognizedText instance.
                return observation.topCandidates(1).first?.string
            }
            
            // Process the recognized strings.
            tag.imageTextContent.append(contentsOf: recognizedStrings)
//            print("Recognized strings: \(recognizedStrings)")
        })
        
        do {
            // Perform the text-recognition request.
            try requestHandler.perform([request])
        } catch {
//            print("Unable to perform the requests: \(error).")
        }
    }
    
    
    
    
    func performVisionActions() {
        if !doImageVision { return }
        // TODO: taggedDirectory acts as a singleton in the application so there is only one instance of it active in normal use
        // but this is called in AddTag and could be called many times before completion
        queue.async { [weak self] in
            for file in self?.files ?? [] {
                for tag in file.tags where tag.recoginitionState == .uninitialized {
                    tag.recoginitionState = .started
                    self?.recognizeText(in: tag)
                    self?.recognizeObjects(in: tag)
                    tag.recoginitionState = .recognized
                }
            }
            
        }
        
    }
    
}

extension TaggedDirectory: NSCopying {
    func copy(with zone: NSZone? = nil) -> Any {
        let d = TaggedDirectory()
        d.directory = directory
        d.files = files.map { $0.copy() as! TaggedFile }
        d.backend = backend?.copy() as? TagBackend
        d.indexMap = indexMap
        d.filterPredicate = filterPredicate
        return d
    }
}

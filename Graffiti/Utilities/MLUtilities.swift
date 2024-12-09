//
//  MLUtilities.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 12/5/24.
//

import Cocoa
import CoreML
import Vision

func recognizeObjects(
    in imageURL: URL, maxResults: Int = 5, precision: Float = 0.8
) throws -> [String] {
    let model = try VNCoreMLModel(
        for: MobileNetV2(configuration: MLModelConfiguration()).model)

    let request = VNCoreMLRequest(model: model)

    guard let nsImage = NSImage(contentsOf: imageURL),
        let cgImage = nsImage.cgImage(
            forProposedRect: nil, context: nil, hints: nil)
    else { return [] }

    let handler = VNImageRequestHandler(ciImage: CIImage(cgImage: cgImage), options: [:])

    try handler.perform([request])

    guard let results = request.results as? [VNClassificationObservation] else {
        return []
    }

    let observations = results[0..<maxResults].filter {
        (!$0.hasPrecisionRecallCurve)
            || ($0.hasPrecisionRecallCurve
                && $0.hasMinimumPrecision(precision, forRecall: precision))
    }.map { $0.identifier }

    return observations
}

enum MLError: Error {
    case noResults
    case belowConfidence
}

func recognizeText(
    in imageURL: URL,
    minHeightPercent: Float = 0.01,
    minConfidence: VNConfidence = 0.0,
    randomized: Bool = false,
    onComplete: @escaping (_ strings: [String]?, _ error: Error?) -> Void
) {
    guard let cgImage = NSImage(byReferencing: imageURL).cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { return }

    let requestHandler = VNImageRequestHandler(cgImage: cgImage)
    let request = VNRecognizeTextRequest(completionHandler: { (request: VNRequest, error: Error?) in
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            onComplete(nil, MLError.noResults)
            return
        }
        let recognizedStrings = observations.compactMap { observation in
            if observation.confidence < minConfidence {
                return ""
            } else {
                return observation.topCandidates(1).first?.string
            }
        }
        onComplete(recognizedStrings, nil)
    })
    request.minimumTextHeight = minHeightPercent  // of image height
    
    do {
        try requestHandler.perform([request])
    } catch {
        onComplete(nil, error)
    }
    
}



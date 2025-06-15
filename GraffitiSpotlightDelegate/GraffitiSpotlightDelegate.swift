//
//  GraffitiSpotlightDelegate.swift
//  GraffitiSpotlightDelegate
//
//  Created by Thomas Povinelli on 12/12/24.
//

import CoreSpotlight

class GraffitiSpotlightDelegate: CSIndexExtensionRequestHandler {

    override func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
    }

    override func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
    }

    override func data(for searchableIndex: CSSearchableIndex, itemIdentifier: String, typeIdentifier: String) throws -> Data {
        return Data()
    }

    override func fileURL(for searchableIndex: CSSearchableIndex, itemIdentifier: String, typeIdentifier: String, inPlace: Bool) throws -> URL {
        return URL(fileURLWithPath: "")
    }
    
    override func searchableIndexDidThrottle(_ searchableIndex: CSSearchableIndex) {
    }

    override func searchableIndexDidFinishThrottle(_ searchableIndex: CSSearchableIndex) {
    }
}

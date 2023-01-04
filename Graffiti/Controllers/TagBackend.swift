//
//  TagBackend.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/1/23.
//

import Foundation

protocol TagBackend {
    func addTag(_ tag: Tag, to file: TaggedFile)
    func removeTag(withID id: Tag.ID, from file: TaggedFile)
    func loadTags(for path: String) -> [Tag]
    func clearTags(of file: TaggedFile)
    
    // used to implement lazy backend systems or other time delay ones
    // exists here because implementers need to see it
    // default does nothing
    func commitTransactions()
}

extension TagBackend {
    // do nothing by default 
    func commitTransactions() {
        
    }
}

//
//  LazyBackend.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/4/23.
//

import Foundation


class LazyBackend: TagBackend {
   
    var implementationProhibitedCharacters: Set<Character> {
        backing.implementationProhibitedCharacters
    }
    
    enum Transaction {
        case Add(tag: Tag, file: TaggedFile)
        case RemoveTag(id: Tag.ID, file: TaggedFile)
        case clearTags(file: TaggedFile)
    }
    
    let backing: TagBackend
    var transactions: [Transaction] = []
    
    init(wrapping backing: TagBackend) {
        self.backing = backing
    }
    
    func addTag(_ tag: Tag, to file: TaggedFile) {
        transactions.append(.Add(tag: tag, file: file))
    }
    
    func removeTag(withID id: Tag.ID, from file: TaggedFile) {
        transactions.append(.RemoveTag(id: id, file: file))
    }
    
    func loadTags(at path: String) -> Set<Tag> {
        backing.loadTags(at: path)
    }
    
    func clearTags(of file: TaggedFile) {
        transactions.append(.clearTags(file: file))
    }
    
    func commitTransactions() {
        for transaction in transactions {
            switch transaction{
            case .Add(let tag, let file):
                backing.addTag(tag, to: file)
            case .RemoveTag(let tag, let file):
                backing.removeTag(withID: tag, from: file)
            case .clearTags(let file):
                backing.clearTags(of: file)
            }
        }
        transactions.removeAll()
        backing.commitTransactions()
    }
}

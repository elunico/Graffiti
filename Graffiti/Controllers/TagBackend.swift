//
//  TagBackend.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/1/23.
//

import Foundation

protocol TagBackend: NSCopying {
    func addTag(_ tag: Tag, to file: TaggedFile)
    func removeTag(withID id: Tag.ID, from file: TaggedFile)
    func loadTags(at path: String) -> Set<Tag>
    func clearTags(of file: TaggedFile)
    func removeTagText(from: TaggedFile)
    
    /// used to implement lazy backend systems or other time delay ones
    /// exists here because implementers need to see it
    /// default does nothing
    ///
    /// SerializedFormat is a representation of the Tags in a serialized
    /// format. This can be void
    func commit(files: [TaggedFile])
    
    /// special characters used by the Tag backend that are
    /// prohibited from being used in Tags themselves
    var implementationProhibitedCharacters: Set<Character> { get }
}

extension TagBackend {
    var prohibitedCharacters: Set<Character> {
        /// This variable exists to be accessed by the program
        /// The program requires these three characters to be prohibited always due to
        /// the search function using these. In addition to these three, implementations
        /// of the tag backend can also prohibit characters hence the union
        /// This property is not declared in the protocol in order to prevent people
        /// from accidentally excluding the 3 special search characters
        Set(["&", "!", "|", "\n", "\t", "\r"]).union(implementationProhibitedCharacters)
    }
}

extension TagBackend {
    // do nothing by default
    func commit(files: [TaggedFile]) {

    }
}


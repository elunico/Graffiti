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
    func commit(files: [TaggedFile], force: Bool)
    
    /// special characters used by the Tag backend that are
    /// prohibited from being used in Tags themselves
    var implementationProhibitedCharacters: Set<Character> { get }

    /// save current data to a temporary save suffixed with `suffix`
    /// the implementer may not support temporary autosaves which would make this a NOP method
    func performAutosave(files: [TaggedFile], suffix: String)
    
    /// remove the temporary save data
    /// the implementer may not support temporary autosaves which would make this a NOP method
    func removeAutosave(suffix: String)
    
    /// should return true if a temporary autosave data exists and can be read/restored
    /// may always return false if the implemented does not support autosave
    func hasAutosave(suffixedWith: String) -> Bool
    
    /// this method should overwrite existing data with the data found in the autosave file
    /// can be a NOP if backend does not support autosave
    func restoreFromAutosave(suffixedWith: String)
    
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
    func commit(files: [TaggedFile], force: Bool) {

    }
}


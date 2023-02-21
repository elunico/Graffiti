//
//  TagTransaction.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/28/23.
//

import Foundation

protocol TagTransaction {
    func perform()
    
    func undo()
    
    func redo()
}

extension TagTransaction {
    func redo() { perform() }
}

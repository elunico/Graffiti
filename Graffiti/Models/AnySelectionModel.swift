//
//  AnySelectionModel.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/20/23.
//

import Foundation

class AnySelectionModel: ObservableObject {
    @Published var selectedItems: [Any] = []
    var isSingleSelected: Bool = false
}

//
//  CachedProperty.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 12/1/24.
//

import Foundation

@propertyWrapper class CachedProperty<Value>: Copyable {
    var backingValue: Value? = nil
    
    var wrappedValue: Value {
        if !isSet {
            backingValue = supplier()
            isSet = true
        }
        return backingValue!
    }
    var isSet: Bool = false
    var supplier: () -> Value

    init(wrappedValue: @autoclosure @escaping () -> Value) {
        self.supplier = wrappedValue
    }
}

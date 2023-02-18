//
//  Utility.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/22/23.
//

import Foundation

import os

func display(message: String, log: OSLog = .default, type: OSLogType = .error) {
    #if DEBUG
    print("[LOG] \(type): \(message)")
    #else
    os_log("%s", log: log, type: type, message)
    #endif 
}

extension Dictionary {
    @discardableResult
    mutating func removeValue(forMaybeKey key: Key?) -> Value? {
        if let key {
            return removeValue(forKey: key)
        }
        return nil
    }
}

protocol AnyOptional {
    associatedtype Element
    var asOptional: Optional<Element> { get }
}

extension Optional: AnyOptional {
    var asOptional: Optional<Wrapped> { self }
}

extension UserDefaults {
    static var thisAppDomain: UserDefaults? {
        UserDefaults(suiteName: "com.tom.graffiti")
    }
}

extension String {
    var lastPathComponent: String {
        (self as NSString).lastPathComponent
    }
}

extension URL {
    var absolutePath: String {
        let s = absoluteString.replacingOccurrences(of: "file://", with: "")
        return s.removingPercentEncoding ?? s
    }
    
    var prettyPrinted: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return absolutePath.replacingOccurrences(of: home.absolutePath, with: "~/")
    }
}

#if DEBUG
func precondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError("precondition failed: \(#file):\(#line) \(message)")
    }
}
#else
@inlinable func precondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    
}
#endif

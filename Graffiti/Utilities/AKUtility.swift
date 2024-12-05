//
//  AKUtility.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 12/4/24.
//

import AppKit

func modalAlert(_ level: NSAlert.Style, message: String, information: String) {
    let a = NSAlert()
    a.messageText = message
    a.informativeText = information
    a.alertStyle = level
    a.runModal()
}

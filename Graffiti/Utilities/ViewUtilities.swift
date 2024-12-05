//
//  ViewUtilities.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/20/23.
//

import SwiftUI


precedencegroup FoldPrecedence {
    lowerThan: AdditionPrecedence
    associativity: left
}

infix operator =>: FoldPrecedence

func => <A, B>(_ lhs: A, _ rhs: B) -> B {
    return rhs
}


extension View {
    func wrapText() -> some View {
        self.frame(
            minWidth: 0,
            maxWidth: .infinity,
            minHeight: 0,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }
}

extension View {
    func onClearAll(message: String, isPresented: Binding<Bool>, clearAction: @escaping () -> ()) -> some View {
        self.confirmationDialog("Are you sure you want to clear all?",
                                isPresented: isPresented) {
            Button("Clear All") {
                clearAction()
            }
        } message: {
            Text(message)
        }
    }
}

enum Orientation {
    case horizontally, vertically
}

func divider(oriented orientation: Orientation, measure: CGFloat) -> some View {
    if (orientation == .horizontally) {
        return Divider().frame(height: measure)
    } else {
        return Divider().frame(width: measure)
    }
}

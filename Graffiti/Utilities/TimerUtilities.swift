//
//  TimerUtils.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/16/23.
//

import Foundation

prefix operator *

prefix func *(_ operand: TimeUnit) -> Double { operand.seconds }

enum TimeUnit {
    static func + (_ lhs: TimeUnit, rhs: TimeUnit) -> TimeUnit {
        lhs.and(rhs)
    }
    
    static func + (_ lhs: TimeUnit, rhs: Double) -> TimeUnit {
        var augmentation: TimeUnit
        switch lhs {
        case .hours(_):
            augmentation = .hours(rhs)
        case .minutes(_):
            augmentation = .minutes(rhs)
        case .seconds(_):
            augmentation = .seconds(rhs)
        case .milliseconds(_):
            augmentation = .milliseconds(rhs)
        }
        return lhs + augmentation
    }
    
    case hours(_ amount: Double)
    case minutes(_ amount: Double)
    case seconds(_ amount: Double)
    case milliseconds(_ amount: Double)
    
    var seconds: Double {
        switch self {
        case .hours(let h):
            return h * 60 * 60
        case .minutes(let m):
            return m * 60
        case .seconds(let s):
            return s
        case .milliseconds(let i):
            return i / 1000.0
        }
    }
    
    func and(_ time: TimeUnit) -> TimeUnit {
        return .seconds(self.seconds + time.seconds)
    }
}

func launch(after time: TimeUnit, repeats: Bool, action: @escaping (Timer) -> ()) -> Timer {
    Timer.scheduledTimer(withTimeInterval: time.seconds, repeats: repeats, block: action)
}

//
//  File.swift
//  
//
//  Created by Саша Восколович on 29.02.2024.
//

import Foundation
import Observation


class Suspect: Observable {
    
    var name: String {
        get {
            access(keyPath: \.name)
            return _name
        }
        set {
            withMutation(keyPath: \.name) {
                _name = newValue
            }
        }
    }
    
    var suspiciousness: Int {
        get {
            access(keyPath: \.suspiciousness)
            return _suspiciousness
        }
        set {
            withMutation(keyPath: \.suspiciousness) {
                _suspiciousness = newValue
            }
        }
    }
    
    init(name: String, suspiciousness: Int) {
        _name = name
        _suspiciousness = suspiciousness
    }
    
    internal nonisolated func access<Member>(keyPath: KeyPath<Suspect, Member>) {
        _$observationRegistrar.access(self, keyPath: keyPath)
    }
    
    internal nonisolated func withMutation<Member, T>(keyPath: KeyPath<Suspect, Member>, _ mutation: () throws -> T) rethrows -> T {
        try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
    }
    
    private var _name: String = ""
    private var _suspiciousness: Int = 0
    private let _$observationRegistrar = ObservationRegistrar()
}

let suspect = Suspect(name: "Darth Vader", suspiciousness: 33)


var ON_CHANGE_CLOSURE: (@Sendable () -> Void)?

class ObservationRegistrar: @unchecked Sendable {
    
    var registry: [AnyKeyPath: (@Sendable () -> Void)] = [:]
    
    func access<Subject, Member>(
        _ subject: Subject,
        keyPath: KeyPath<Subject, Member>
    ) where Subject : Observable {
        print("access \(keyPath)")
        if let closure =  ON_CHANGE_CLOSURE {
            registry[keyPath] = closure
        }
    }
    
    
    func withMutation<Subject, Member, T>(
        of subject: Subject,
        keyPath: KeyPath<Subject, Member>,
        _ mutation: () throws -> T
    ) rethrows -> T where Subject : Observable {
        print("mutation \(keyPath)")
        if let closure = registry.removeValue(forKey: keyPath) {
            closure()
        }
        return try mutation()
    }
}




public func withObservationTracking<T>(
    _ apply: () -> T,
    onChange: @escaping @Sendable () -> Void
) -> T {
    print("Setting the global ON_CHANGE_CLOSURE")
    ON_CHANGE_CLOSURE = onChange
    
    
    let result = apply()
    
    return result
}



withObservationTracking {
  print("I am observing \(suspect.name)")
} onChange: {
  print("Name changed!")
}

suspect.name = "New Name"
//suspect.suspiciousness = 12

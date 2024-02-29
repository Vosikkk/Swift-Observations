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

withObservationTracking {
    print("I am observing \(suspect.name)")
} onChange: {
    print("Name changed!")
}

print(suspect.name)

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
    
    var registry: [AnyKeyPath: Set<Observation.ID>] = [:]
    var observations: [Observation.ID: Observation] = [:]
    
    struct Observation: Identifiable {
        let id: UUID = UUID()
        let keyPaths: Set<AnyKeyPath>
        let closure: @Sendable () -> Void
    }
    
    func registerOnChange(
        _ keyPaths: Set<AnyKeyPath>,
        _ onChange: @escaping @Sendable () -> Void
    ) {
        let observation = Observation(keyPaths: keyPaths, closure: onChange)
        observations[observation.id] = observation
        for keyPath in keyPaths {
            registry[keyPath, default: []].insert(observation.id)
        }
    }
    
    
    func access<Subject, Member>(
        _ subject: Subject,
        keyPath: KeyPath<Subject, Member>
    ) where Subject : Observable {
        print("access \(keyPath)")
        GLOBAL_ACCESS_LIST?.trackAccess(self, keyPath: keyPath)
    }
    
    
    func withMutation<Subject, Member, T>(
        of subject: Subject,
        keyPath: KeyPath<Subject, Member>,
        _ mutation: () throws -> T
    ) rethrows -> T where Subject : Observable {
        print("mutation \(keyPath)")
        
        return try mutation()
    }
}

var GLOBAL_ACCESS_LIST: AccessList?

struct AccessList {
    
    struct Entry {
        var registrar: ObservationRegistrar
        var keyPaths: Set<AnyKeyPath> = []
    }
    
    var entries: [ObjectIdentifier: Entry] = [:]
    
    mutating func trackAccess(_ registrar: ObservationRegistrar, keyPath: AnyKeyPath) {
        let id = ObjectIdentifier(registrar)
        entries[id, default: Entry(registrar: registrar)].keyPaths.insert(keyPath)
    }
    
    func registerOnChange(_ onChange: @escaping @Sendable () -> Void) {
        for entry in entries {
            let registrar = entry.value.registrar
            let keyPaths = entry.value.keyPaths
            registrar.registerOnChange(
                keyPaths,
                onChange
            )
        }
    }
}



public func withObservationTracking<T>(
    _ apply: () -> T,
    onChange: @escaping @Sendable () -> Void
) -> T {
    // 1. Set a global closure
    // 2. call apply()
    // 3. suspect.access(\.name)
    GLOBAL_ACCESS_LIST = AccessList()
    
    let result = apply()
    
    GLOBAL_ACCESS_LIST?.registerOnChange(onChange)
    
    return result
}



withObservationTracking {
    print("I am observing \(suspect.name) \(suspect.suspiciousness)/")
} onChange: {
  print("Name changed!")
}

suspect.name = "New Name"
suspect.suspiciousness = 12

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
let suspect2 = Suspect(name: "Old Name", suspiciousness: 45)


var ON_CHANGE_CLOSURE: (@Sendable () -> Void)?

class ObservationRegistrar: @unchecked Sendable {
    
    var lookups: [AnyKeyPath: Set<Observation.ID>] = [:]
    var observations: [Observation.ID: Observation] = [:]
    
    struct Observation: Identifiable {
        let id: UUID = UUID()
        let keyPaths: Set<AnyKeyPath>
        let closure: @Sendable () -> Void
    }
    
    func cancel(_ observationId: Observation.ID) {
        print("Should Cancel \(observationId)")
        
        if let observation = observations.removeValue(forKey: observationId) {
            for keyPath in observation.keyPaths {
                lookups[keyPath]?.remove(observation.id)
                if (lookups[keyPath]?.isEmpty ?? false) {
                    lookups.removeValue(forKey: keyPath)
                }
            }
        }
    }
    
    func registerOnChange(_ keyPaths: Set<AnyKeyPath>, _ onChange: @escaping @Sendable () -> Void) -> Observation.ID {
        let observation = Observation(keyPaths: keyPaths, closure: onChange)
        observations[observation.id] = observation
        for keyPath in keyPaths {
            lookups[keyPath, default: []].insert(observation.id)
        }
        return observation.id
    }
    
    
    func access<Subject, Member>(_ subject: Subject, keyPath: KeyPath<Subject, Member>) where Subject : Observable {
        print("access \(keyPath)")
        GLOBAL_ACCESS_LIST?.trackAccess(self, keyPath: keyPath)
    }
    
    
    func withMutation<Subject, Member, T>(of subject: Subject, keyPath: KeyPath<Subject, Member>, _ mutation: () throws -> T) rethrows -> T where Subject : Observable {
        print("mutation \(keyPath)")
        
        if let observationIds = lookups.removeValue(forKey: keyPath) {
            for observationId in observationIds {
                if let observation = observations.removeValue(forKey: observationId) {
                    observation.closure()
                    
                    for keyPath in observation.keyPaths {
                        lookups[keyPath]?.remove(observation.id)
                        if (lookups[keyPath]?.isEmpty ?? false) {
                            lookups.removeValue(forKey: keyPath)
                        }
                    }
                }
            }
        }
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
        
        
        let observationIds: Box<[ObjectIdentifier: ObservationRegistrar.Observation.ID]> = Box(value: [:])
        
        let cancellingOnChange: @Sendable () -> Void = {
            onChange()
            
            // cancel the observations on every registrar
            
            for (registrarId, observationId) in observationIds.value {
                entries[registrarId]?.registrar.cancel(observationId)
            }
        }
        
        for entry in entries {
            let registrar = entry.value.registrar
            let keyPaths = entry.value.keyPaths
            
            let observationId = registrar.registerOnChange(keyPaths,cancellingOnChange)
            
            observationIds.value[entry.key] = observationId
        }
    }
}

class Box<A> {
    
    var value: A
    
    init(value: A) {
        self.value = value
    }
}


public func withObservationTracking<T>(_ apply: () -> T, onChange: @escaping @Sendable () -> Void) -> T {
    // 1. Set a global closure
    // 2. call apply()
    // 3. suspect.access(\.name)
    GLOBAL_ACCESS_LIST = AccessList()
    
    let result = apply()
    
    GLOBAL_ACCESS_LIST?.registerOnChange(onChange)
    
    return result
}



withObservationTracking {
    print("I am observing \(suspect.name) \(suspect.suspiciousness)")
    print("I am observing \(suspect2.name) \(suspect2.suspiciousness)")
} onChange: {
  print("Name changed!")
}

suspect.name = "New Name"
suspect2.suspiciousness = 12


suspect2.name = "New Name"
suspect.suspiciousness = 10

//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental)
extension Test {
  public protocol __Observer: Sendable {
    init() async
    func observe(_ event: borrowing Event, in context: borrowing Event.Context)
  }
}

// MARK: - Macro

@_spi(Experimental)
public protocol __TestObserver: Sendable {
  associatedtype __Observer: Test.__Observer
}

@_spi(Experimental)
@attached(extension, conformances: Test.__Observer)
public macro Observer() = #externalMacro(module: "TestingMacros", type: "ObserverDeclarationMacro")

// MARK: - Attaching to a configuration

extension Configuration {
  /// A string that appears within all auto-generated types conforming to the
  /// `__TestObserver` protocol.
  private static let _testObserverTypeNameMagic = "__🟠$test_observer__"

  private static var _allObservers: [any Test.__Observer] {
    get async {
      await withTaskGroup(of: (any Test.__Observer).self) { taskGroup in
        func addConcreteTestObserver<T>(_ type: T.Type) where T: __TestObserver {
          taskGroup.addTask {
            await type.__Observer()
          }
        }
        enumerateTypes(withNamesContaining: _testObserverTypeNameMagic) { type, _ in
          if let type = type as? any __TestObserver.Type {
            addConcreteTestObserver(type)
          }
        }

        return await taskGroup.reduce(into: []) { $0.append($1) }
      }
    }
  }

  mutating func attachObservers() async {
    let observers = await Self._allObservers
    if observers.isEmpty {
      return
    }

    eventHandler = { [oldEventHandler = eventHandler] event, context in
      for observer in observers {
        observer.observe(event, in: context)
      }
      oldEventHandler(event, context)
    }
  }
}

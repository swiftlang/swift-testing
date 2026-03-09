//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals
private import Builtin

extension __ExpectationContext {
  @_addressableForDependencies
  public struct ObservedValue<T>: ~Copyable, ~Escapable where T: ~Copyable & ~Escapable {
    private var _expectationContext: __ExpectationContext

    private enum _Storage: ~Copyable & ~Escapable {
      case byValue(T)
      case byAddress(Builtin.RawPointer)

      var value: T {
        @_lifetime(borrow self)
        _read {
          switch self {
          case let .byValue(value):
            yield value
          case .byAddress:
            Builtin.unreachable()
          }
        }
      }

      var address: Builtin.RawPointer {
        switch self {
        case .byValue:
          Builtin.unreachable()
        case let .byAddress(address):
          address
        }
      }
    }

    private var _storage: _Storage

    private var _observe: (borrowing Self, __ExpressionID) -> Void

    @_lifetime(immortal)
    @available(*, unavailable)
    init() {
      Builtin.unreachable()
    }
  }

  extension ObservedValue where T: Copyable & Escapable {
    @_lifetime(immortal)
    init(_ value: borrowing @_addressable T, in expectationContext: __ExpectationContext) {
      _expectationContext = expectationContext
      _storage = .byAddress(Builtin.addressOfBorrow(value))
      _observe = { self, id in
        let address = UnsafePointer<T>(self._storage.address)
        self._expectationContext.captureValue(value, identifiedBy: id)
      }
    }

    public subscript(id: __ExpressionID) -> T {
      unsafeAddress {
        _observe(_storage)
        return UnsafePointer(_storage.address)
      }
      nonmutating unsafeMutableAddress {
        UnsafeMutablePointer(_storage.address)
      }
    }
  }

  @available(*, unavailable, message: "Cannot capture a value with suppressed conformances to both 'Copyable' and 'Escapable' in an expectation expressions")
  extension ObservedValue where T: ~Copyable & ~Escapable {
    @_lifetime(immortal)
    init(_ value: borrowing T, in expectationContext: __ExpectationContext) {
      Builtin.unreachable()
    }

    public subscript() -> T {
      @_lifetime(immortal)
      _read {
        Builtin.unreachable()
      }
      @_lifetime(&self)
      nonmutating _modify {
        Builtin.unreachable()
      }
    }
  }

  extension ObservedValue where T: Copyable & ~Escapable {
    @_lifetime(copy value)
    init(_ value: borrowing T, in expectationContext: __ExpectationContext) {
      _expectationContext = expectationContext
      _storage = .byValue(copy value)
      _observe = { self, id in
        self._expectationContext.captureValue(self._storage.value, id)
      }
    }

    public subscript() -> T {
      @_lifetime(borrow self)
      _read {
        _observe(_storage)
        yield _storage.value
      }

      @_lifetime(&self)
      @available(*, unavailable, message: "Cannot mutate a value with suppressed conformance to 'Escapable' in an expectation expression")
      nonmutating _modify {
        Builtin.unreachable()
      }
    }
  }

  extension ObservedValue where T: ~Copyable & Escapable {
    init(_ value: borrowing @_addressable T, in expectationContext: __ExpectationContext) {
      _expectationContext = expectationContext
      _storage = .byAddress(Builtin.addressOfBorrow(value))
      _observe = { self, id in
        let address = UnsafePointer<T>(self._storage.address)
        self._expectationContext.captureValue(value, identifiedBy: id)
      }
    }

    public subscript() -> T {
      unsafeAddress {
        _observe(_storage)
        return UnsafePointer(_storage.address)
      }
      nonmutating unsafeMutableAddress {
        UnsafeMutablePointer(_storage.address)
      }
    }
  }
}
//
//@Test func flooble() {
//  do {
//    struct B: Equatable {
//      var x: Int
//
//      mutating func add(_ y: Int) {
//        print("Adding \(x) + \(y)")
//        x += y
//      }
//    }
//    var lhs = B(x: 1)
//    let rhs = B(x: 2)
//    let lhso = ObservedValue(lhs)
//    let rhso = ObservedValue(rhs)
//    _ = lhso[] == rhso[]
//    lhso[].add(100)
//    _ = lhso[] == rhso[]
//  }
//
//  do {
//    struct NE: ~Escapable, Equatable {
//      var x: Int
//    }
//    let lhs = NE(x: 1)
//    let rhs = NE(x: 2)
//    let lhso = ObservedValue(lhs)
//    let rhso = ObservedValue(rhs)
//    _ = lhso[] == rhso[]
//  }
//
//  do {
//    struct NC: ~Copyable, Equatable {
//      var x: Int
//
//      mutating func add(_ y: Int) {
//        print("Adding \(x) + \(y)")
//        x += y
//      }
//    }
//    var lhs = NC(x: 1)
//    let rhs = NC(x: 2)
//    let lhso = ObservedValue(lhs)
//    let rhso = ObservedValue(rhs)
//    _ = lhso[] == rhso[]
//    lhso[].add(100)
//    _ = lhso[] == rhso[]
//  }
//}
//

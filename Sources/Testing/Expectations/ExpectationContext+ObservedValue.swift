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

    private var _captureValue: (borrowing Self) -> Void

    @_lifetime(immortal)
    @available(*, unavailable)
    init() {
      Builtin.unreachable()
    }
  }
}

@available(*, unavailable)
extension __ExpectationContext.ObservedValue: Sendable {}

extension __ExpectationContext.ObservedValue where T: Copyable & Escapable {
  @_lifetime(immortal)
  init(_ value: borrowing @_addressable T, identifiedBy id: __ExpressionID, in expectationContext: __ExpectationContext) {
    _expectationContext = expectationContext
    _storage = .byAddress(Builtin.addressOfBorrow(value))
    _captureValue = { ov in
      let address = UnsafePointer<T>(ov._storage.address)
      ov._expectationContext.captureValue(address.pointee, identifiedBy: id)
    }
  }

  public subscript() -> T {
    unsafeAddress {
      _captureValue(self)
      return UnsafePointer(_storage.address)
    }
    nonmutating unsafeMutableAddress {
      UnsafeMutablePointer(_storage.address)
    }
  }
}

@available(*, unavailable, message: "Cannot capture a value with suppressed conformances to both 'Copyable' and 'Escapable' in an expectation expressions")
extension __ExpectationContext.ObservedValue where T: ~Copyable & ~Escapable {
  @_lifetime(immortal)
  init(_ value: borrowing T, identifiedBy id: __ExpressionID, in expectationContext: __ExpectationContext) {
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

extension __ExpectationContext.ObservedValue where T: Copyable & ~Escapable {
  @_lifetime(copy value)
  init(_ value: borrowing T, identifiedBy id: __ExpressionID, in expectationContext: __ExpectationContext) {
    _expectationContext = expectationContext
    _storage = .byValue(copy value)
    _captureValue = { ov in
      let value = ov._storage.value
      ov._expectationContext.captureValue(value, identifiedBy: id)
    }
  }

  public subscript() -> T {
    @_lifetime(borrow self)
    _read {
      _captureValue(self)
      yield _storage.value
    }

    @_lifetime(&self)
    @available(*, unavailable, message: "Cannot mutate a value with suppressed conformance to 'Escapable' in an expectation expression")
    nonmutating _modify {
      Builtin.unreachable()
    }
  }
}

extension __ExpectationContext.ObservedValue where T: ~Copyable & Escapable {
  @_lifetime(borrow value)
  init(_ value: borrowing @_addressable T, identifiedBy id: __ExpressionID, in expectationContext: __ExpectationContext) {
    _expectationContext = expectationContext
    _storage = .byAddress(Builtin.addressOfBorrow(value))
    _captureValue = { ov in
      let address = UnsafePointer<T>(ov._storage.address)
      ov._expectationContext.captureValue(address.pointee, identifiedBy: id)
    }
  }

  public subscript() -> T {
    unsafeAddress {
      _captureValue(self)
      return UnsafePointer(_storage.address)
    }
    nonmutating unsafeMutableAddress {
      UnsafeMutablePointer(_storage.address)
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

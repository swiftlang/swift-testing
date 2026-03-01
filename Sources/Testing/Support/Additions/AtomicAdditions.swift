//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import _TestingInternals

#if canImport(Synchronization)
internal import Synchronization
#endif

#if SWT_TARGET_OS_APPLE
/// A type that replicates the interface of ``Synchronization/Atomic``.
///
/// This type is used on Apple platforms because our deployment target there is
/// earlier than the availability of the ``Synchronization/Atomic`` type. It
/// replicates the interface of that type but is implemented differently (using
/// a mutex instead of actual atomic operations).
///
/// Since we don't try to implement the ``Synchronization/AtomicRepresentable``
/// protocol, this implementation only supports using a few types (i.e. the
/// integers and `Bool`).
struct Atomic<Value>: ~Copyable where Value: Sendable {
  /// Storage for the underlying mutex.
  private var _mutex: Mutex<Value>

  init(_ value: consuming sending Value) where Value == Bool {
    _mutex = Mutex(value)
  }

  init(_ value: consuming sending Value) where Value: BinaryInteger {
    _mutex = Mutex(value)
  }

  /// The orderings supported by this type.
  ///
  /// Because this type implements atomic operations using a mutex, all of its
  /// operations are inherently sequentially consistent.
  ///
  /// For more information, see [`AtomicUpdateOrdering`](https://developer.apple.com/documentation/synchronization/atomicupdateordering).
  enum Ordering {
    case sequentiallyConsistent
  }
}

extension Atomic: Sendable where Value: Sendable {}

// MARK: -

extension Atomic {
  func load(ordering: Ordering) -> Value {
    _mutex.rawValue
  }

  func store(_ desired: consuming Value, ordering: Ordering) {
    _mutex.withLock { $0 = copy desired }
  }
}

extension Atomic where Value: Equatable {
  func compareExchange(expected: consuming Value, desired: consuming Value, ordering: Ordering) -> (exchanged: Bool, original: Value) {
    _mutex.withLock { value in
      let original = value
      guard original == expected else {
        return (false, original)
      }
      value = copy desired
      return (true, original)
    }
  }
}

extension Atomic where Value: AdditiveArithmetic {
  @discardableResult
  func add(_ operand: Value, ordering: Ordering) -> (oldValue: Value, newValue: Value) {
    _mutex.withLock { value in
      let oldValue = value
      value += operand
      let newValue = value
      return (oldValue, newValue)
    }
  }

  @discardableResult
  func subtract(_ operand: Value, ordering: Ordering) -> (oldValue: Value, newValue: Value) {
    _mutex.withLock { value in
      let oldValue = value
      value -= operand
      let newValue = value
      return (oldValue, newValue)
    }
  }
}
#endif

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
/// a heap-allocated value) with support for only those atomic operations that
/// we need to use in the testing library.
///
/// Since we don't try to implement the complete ``Synchronization/AtomicRepresentable``
/// protocol, this implementation only supports using a few types that are
/// actually in use in the testing library.
struct Atomic<Value>: ~Copyable {
  /// Storage for the underlying atomic value.
  private nonisolated(unsafe) var _address: UnsafeMutablePointer<Value>

  init(_ value: consuming sending Value) {
    _address = .allocate(capacity: 1)
    _address.initialize(to: value)
  }

  deinit {
    _address.deinitialize(count: 1)
    _address.deallocate()
  }

  /// The orderings supported by this type.
  ///
  /// At this time, we only implement sequentially consistent ordering. For more
  /// information about atomic operation ordering, see [`AtomicUpdateOrdering`](https://developer.apple.com/documentation/synchronization/atomicupdateordering).
  enum Ordering {
    case sequentiallyConsistent
  }
}

extension Atomic: Sendable where Value: Sendable {}

// MARK: - Atomic<Bool>

extension Atomic where Value == Bool {
  func load(ordering: Ordering) -> Value {
    swt_atomicLoad(_address)
  }

  func store(_ desired: consuming Value, ordering: Ordering) {
    swt_atomicStore(_address, desired)
  }

  func compareExchange(expected: consuming Value, desired: consuming Value) -> (exchanged: Bool, original: Value) {
    var expected = expected
    let exchanged = swt_atomicCompareExchange(_address, &expected, desired)
    return (exchanged, expected)
  }
}

// MARK: - Atomic<CInt>

extension Atomic where Value == CInt {
  func load(ordering: Ordering) -> Value {
    return swt_atomicLoad(_address)
  }

  func store(_ desired: consuming Value, ordering: Ordering) {
    swt_atomicStore(_address, desired)
  }

  func compareExchange(expected: consuming Value, desired: consuming Value, ordering: Ordering) -> (exchanged: Bool, original: Value) {
    var expected = expected
    let exchanged = swt_atomicCompareExchange(_address, &expected, desired)
    return (exchanged, expected)
  }
}

// MARK: - Atomic<Int>

extension Atomic where Value == Int {
  func load(ordering: Ordering) -> Value {
    swt_atomicLoad(_address)
  }

  func store(_ desired: consuming Value, ordering: Ordering) {
    swt_atomicStore(_address, desired)
  }

  func compareExchange(expected: consuming Value, desired: consuming Value, ordering: Ordering) -> (exchanged: Bool, original: Value) {
    var expected = expected
    let exchanged = swt_atomicCompareExchange(_address, &expected, desired)
    return (exchanged, expected)
  }

  @discardableResult
  func add(_ operand: Value, ordering: Ordering) -> (oldValue: Value, newValue: Value) {
    while true {
      let oldValue = load(ordering: ordering)
      let newValue = oldValue + operand
      if compareExchange(expected: oldValue, desired: newValue, ordering: ordering).exchanged {
        return (oldValue, newValue)
      }
    }
  }

  @discardableResult
  func subtract(_ operand: Value, ordering: Ordering) -> (oldValue: Value, newValue: Value) {
    add(-operand, ordering: ordering)
  }
}
#endif

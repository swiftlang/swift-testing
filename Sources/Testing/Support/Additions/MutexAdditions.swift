//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import _TestingInternals
#if canImport(Synchronization)
private import Synchronization
#endif

#if SWT_TARGET_OS_APPLE && !SWT_NO_OS_UNFAIR_LOCK
/// A type that replicates the interface of ``Synchronization/Mutex``.
///
/// This type is used on Apple platforms because our deployment target there is
/// earlier than the availability of the ``Synchronization/Mutex`` type. It
/// replicates the interface of that type but is implemented differently (using
/// heap-allocated storage for the underlying lock and the value it guards).
struct Mutex<Value>: Sendable, ~Copyable where Value: ~Copyable {
  /// Storage for the underlying lock and the value it guards.
  private nonisolated(unsafe) let _storage: UnsafeMutableRawPointer

  public init(_ initialValue: consuming sending Value) {
    _storage = UnsafeMutableRawPointer.allocate(
      byteCount: Self._valueOffset + MemoryLayout<Value>.size,
      alignment: max(MemoryLayout<os_unfair_lock_s>.alignment, MemoryLayout<Value>.alignment)
    )
    let (lock, value) = _lockAndValueAddresses
    lock.initialize(to: .init())
    value.initialize(to: initialValue)
  }

  deinit {
    do {
      let (lock, value) = _lockAndValueAddresses
      value.deinitialize(count: 1)
      lock.deinitialize(count: 1)
    }
    _storage.deallocate()
  }

  /// The offset into an instance's storage where the value it guards is stored.
  private static var _valueOffset: Int {
    max(MemoryLayout<os_unfair_lock_s>.stride, MemoryLayout<Value>.alignment)
  }

  /// Pointers to this instance's underlying lock and the value it guards.
  ///
  /// - Important: These pointers are only valid for the lifetime of `self`.
  private var _lockAndValueAddresses: (lock: UnsafeMutablePointer<os_unfair_lock_s>, value: UnsafeMutablePointer<Value>) {
    let lock = _storage.bindMemory(to: os_unfair_lock_s.self, capacity: 1)
    let value = (_storage + Self._valueOffset).bindMemory(to: Value.self, capacity: 1)
    return (lock, value)
  }

  /// Acquire the lock.
  ///
  /// See ``Synchronization/Mutex/withLock(_:)`` for more details.
  borrowing func withLock<R, E>(_ body: (inout sending Value) throws(E) -> sending R) throws(E) -> sending R where R: ~Copyable {
    let (lock, value) = _lockAndValueAddresses
    os_unfair_lock_lock(lock)
    defer {
      os_unfair_lock_unlock(lock)
    }
    return try body(&value.pointee)
  }

  /// Acquire the lock if available.
  ///
  /// See ``Synchronization/Mutex/withLockIfAvailable(_:)`` for more details.
  borrowing func withLockIfAvailable<R, E>(_ body: (inout sending Value) throws(E) -> sending R) throws(E) -> sending R? where R: ~Copyable {
    let (lock, value) = _lockAndValueAddresses
    guard os_unfair_lock_trylock(lock) else {
      return nil
    }
    defer {
      os_unfair_lock_unlock(lock)
    }
    return try body(&value.pointee)
  }
}
#elseif !canImport(Synchronization)
#error("Platform-specific misconfiguration: Mutex is unavailable")
#endif

extension Mutex where Value: Copyable {
  var rawValue: Value {
    withLock { $0 }
  }
}

// MARK: - Additions

extension Mutex where Value: AdditiveArithmetic & Sendable {
  /// Add something to the current wrapped value of this instance.
  ///
  /// - Parameters:
  ///   - addend: The value to add.
  ///
  /// - Returns: The sum of ``rawValue`` and `addend`.
  @discardableResult func add(_ addend: Value) -> Value {
    withLock { rawValue in
      let result = rawValue + addend
      rawValue = result
      return result
    }
  }
}

extension Mutex where Value: Numeric & Sendable {
  /// Increment the current wrapped value of this instance.
  ///
  /// - Returns: The sum of ``rawValue`` and `1`.
  ///
  /// This function is exactly equivalent to `add(1)`.
  @discardableResult func increment() -> Value {
    add(1)
  }

  /// Decrement the current wrapped value of this instance.
  ///
  /// - Returns: The sum of ``rawValue`` and `-1`.
  ///
  /// This function is exactly equivalent to `add(-1)`.
  @discardableResult func decrement() -> Value {
    add(-1)
  }
}

extension Mutex where Value: ~Copyable {
  /// Initialize an instance of this type with a raw value of `nil`.
  init<V>() where Value == V?, V: ~Copyable {
    self.init(nil)
  }

  /// Initialize an instance of this type with a raw value of `[:]`.
  init<K, V>() where Value == Dictionary<K, V> {
    self.init([:])
  }

  /// Initialize an instance of this type with a raw value of `[]`.
  init<V>() where Value == [V] {
    self.init([])
  }
}

// MARK: - POSIX conveniences

#if os(FreeBSD) || os(OpenBSD)
typealias pthread_mutex_t = _TestingInternals.pthread_mutex_t?
typealias pthread_cond_t = _TestingInternals.pthread_cond_t?
#endif

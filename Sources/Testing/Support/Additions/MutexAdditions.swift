//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import _TestingInternals

#if canImport(Synchronization)
internal import Synchronization
#endif

/// # Q: When should I use `Mutex<T>` vs. `Allocated<Mutex<T>>`?
///
/// **A (short):** Whenever the compiler lets you use `Mutex<T>`, use that.
///
/// **A (long):** Mutexes can generally be locally allocated when they are
///   function-local, global, or `static`. If your mutex is an instance member
///   of a reference type (a class or actor), you again generally won't need
///   `Allocated`. If, however, you need a mutex to be an instance member of a
///   copyable value type (a structure or enumeration), then it _must_ be boxed
///   with `Allocated` (or something else that moves its storage onto the heap).

#if SWT_TARGET_OS_APPLE
/// A type that replicates the interface of ``Synchronization/Mutex``.
///
/// This type is used on Apple platforms because our deployment target there is
/// earlier than the availability of the ``Synchronization/Mutex`` type. It
/// replicates the interface of that type but is implemented differently (using
/// heap-allocated storage for the underlying lock and the value it guards).
struct Mutex<Value>: Sendable, ~Copyable where Value: ~Copyable {
  /// The underlying lock type.
#if !SWT_NO_OS_UNFAIR_LOCK
  private typealias _Lock = os_unfair_lock_s
#else
  private typealias _Lock = pthread_mutex_t
#endif

  /// Storage for the underlying lock.
  private nonisolated(unsafe) let _lockAddress: UnsafeMutablePointer<_Lock>

  /// Storage for the value this instance guards.
  private nonisolated(unsafe) let _valueAddress: UnsafeMutablePointer<Value>

  public init(_ initialValue: consuming sending Value) {
    _lockAddress = .allocate(capacity: 1)
#if !SWT_NO_OS_UNFAIR_LOCK
    _lockAddress.initialize(to: .init())
#else
    _ = pthread_mutex_init(_lockAddress, nil)
#endif
    _valueAddress = .allocate(capacity: 1)
    _valueAddress.initialize(to: initialValue)
  }

  deinit {
    _valueAddress.deinitialize(count: 1)
    _valueAddress.deallocate()
#if !SWT_NO_OS_UNFAIR_LOCK
    _lockAddress.deinitialize(count: 1)
#else
    _ = pthread_mutex_destroy(_lockAddress)
#endif
    _lockAddress.deallocate()
  }

  /// Acquire the lock.
  ///
  /// See ``Synchronization/Mutex/withLock(_:)`` for more details.
  borrowing func withLock<R, E>(_ body: (inout sending Value) throws(E) -> sending R) throws(E) -> sending R where R: ~Copyable {
    let lock = _lockAddress
#if !SWT_NO_OS_UNFAIR_LOCK
    os_unfair_lock_lock(lock)
    defer {
      os_unfair_lock_unlock(lock)
    }
#else
    _ = pthread_mutex_lock(lock)
    defer {
      _ = pthread_mutex_unlock(lock)
    }
#endif
    return try body(&_valueAddress.pointee)
  }

  /// Acquire the lock if available.
  ///
  /// See ``Synchronization/Mutex/withLockIfAvailable(_:)`` for more details.
  borrowing func withLockIfAvailable<R, E>(_ body: (inout sending Value) throws(E) -> sending R) throws(E) -> sending R? where R: ~Copyable {
    let lock = _lockAddress
#if !SWT_NO_OS_UNFAIR_LOCK
    guard os_unfair_lock_trylock(lock) else {
      return nil
    }
    defer {
      os_unfair_lock_unlock(lock)
    }
#else
    guard 0 == pthread_mutex_trylock(lock) else {
      return nil
    }
    defer {
      _ = pthread_mutex_unlock(lock)
    }
#endif
    return try body(&_valueAddress.pointee)
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

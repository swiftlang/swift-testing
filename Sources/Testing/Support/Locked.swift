//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import _TestingInternals

/// A type that wraps a value requiring access from a synchronous caller during
/// concurrent execution.
///
/// Instances of this type use a lock to synchronize access to their raw values.
/// The lock is not recursive. If the type of the lock is ``/Swift/Never``, no
/// locking is performed.
///
/// Instances of this type can be used to synchronize access to shared data from
/// a synchronous caller. Wherever possible, use actor isolation or other Swift
/// concurrency tools.
///
/// This type is not part of the public interface of the testing library.
struct CustomLocked<T, Lock>: RawRepresentable, Sendable where T: Sendable, Lock: Lockable {
  /// The underlying lock type.
  typealias Lock = Lock

  /// A type providing heap-allocated storage for an instance of ``Locked``.
  private final class _Storage: ManagedBuffer<T, Lock> {
    deinit {
      withUnsafeMutablePointerToElements { lock in
        Lock.deinitialize(at: lock)
      }
    }
  }

  /// Storage for the underlying lock and wrapped value.
  private nonisolated(unsafe) var _storage: ManagedBuffer<T, Lock>

  init(rawValue: T) {
    _storage = _Storage.create(minimumCapacity: 1, makingHeaderWith: { _ in rawValue })
    _storage.withUnsafeMutablePointerToElements { lock in
      Lock.initialize(at: lock)
    }
  }

  var rawValue: T {
    withLock { $0 }
  }

  /// Acquire the lock and invoke a function while it is held.
  ///
  /// - Parameters:
  ///   - body: A closure to invoke while the lock is held.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  ///
  /// This function can be used to synchronize access to shared data from a
  /// synchronous caller. Wherever possible, use actor isolation or other Swift
  /// concurrency tools.
  nonmutating func withLock<R>(_ body: @Sendable (inout T) throws -> sending R) rethrows -> sending R {
    try _storage.withUnsafeMutablePointerToElements { lock in
      try Lock.withLock(at: lock) {
        try _storage.withUnsafeMutablePointerToHeader { rawValue in
          try body(&rawValue.pointee)
        }
      }
    }
  }

  /// Acquire the lock and invoke a function while it is held, yielding both the
  /// protected value and a reference to the lock itself.
  ///
  /// - Parameters:
  ///   - body: A closure to invoke while the lock is held.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  ///
  /// This function is equivalent to ``withLock(_:)`` except that the closure
  /// passed to it also takes a reference to the underlying platform lock. This
  /// function can be used when platform-specific functionality such as a
  /// `pthread_cond_t` is needed. Because the caller has direct access to the
  /// lock and is able to unlock and re-lock it, it is unsafe to modify the
  /// protected value.
  ///
  /// - Warning: Callers that unlock the lock _must_ lock it again before the
  ///   closure returns. If the lock is not acquired when `body` returns, the
  ///   effect is undefined.
  nonmutating func withUnsafeUnderlyingLock<R>(_ body: @Sendable (UnsafeMutablePointer<Lock>, T) throws -> sending R) rethrows -> sending R {
    try _storage.withUnsafeMutablePointerToElements { lock in
      try Lock.withLock(at: lock) {
        try _storage.withUnsafeMutablePointers { rawValue, lock in
          try body(lock, rawValue.pointee)
        }
      }
    }
  }
}

// MARK: - Platform-specific default lock

/// The platform-specific lock type used by ``Locked``.
///
/// To use a different type as the underlying lock, use ``CustomLocked``.

/// A type that wraps a value requiring access from a synchronous caller during
/// concurrent execution.
///
/// Instances of this type use a lock to synchronize access to their raw values.
/// The lock is not recursive.
///
/// Instances of this type can be used to synchronize access to shared data from
/// a synchronous caller. Wherever possible, use actor isolation or other Swift
/// concurrency tools.
///
/// This type uses the optimal available platform-specific lock type. To use a
/// different type as the underlying lock, use ``CustomLocked``.
///
/// This type is not part of the public interface of the testing library.
#if SWT_TARGET_OS_APPLE && canImport(os)
typealias Locked<T> = CustomLocked<T, os_unfair_lock>
#elseif SWT_TARGET_OS_APPLE
typealias Locked<T> = CustomLocked<T, pthread_mutex_t>
#else
typealias Locked<T> = CustomLocked<T, Mutex<Void>>
#endif

// MARK: - Type-specific conveniences

extension CustomLocked where T: AdditiveArithmetic {
  /// Add something to the current wrapped value of this instance.
  ///
  /// - Parameters:
  ///   - addend: The value to add.
  ///
  /// - Returns: The sum of ``rawValue`` and `addend`.
  @discardableResult func add(_ addend: T) -> T {
    withLock { rawValue in
      let result = rawValue + addend
      rawValue = result
      return result
    }
  }
}

extension CustomLocked where T: Numeric {
  /// Increment the current wrapped value of this instance.
  ///
  /// - Returns: The sum of ``rawValue`` and `1`.
  ///
  /// This function is exactly equivalent to `add(1)`.
  @discardableResult func increment() -> T {
    add(1)
  }
}

extension CustomLocked {
  /// Initialize an instance of this type with a raw value of `nil`.
  init<V>() where T == V? {
    self.init(rawValue: nil)
  }

  /// Initialize an instance of this type with a raw value of `[:]`.
  init<K, V>() where T == Dictionary<K, V> {
    self.init(rawValue: [:])
  }
}

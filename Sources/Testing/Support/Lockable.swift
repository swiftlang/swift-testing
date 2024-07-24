//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import _TestingInternals
import Synchronization

/// A protocol describing a type that can be locked.
///
/// Lockable types are assumed to be address-sensitive, so all of this
/// protocol's requirements are static and take pointers to instances of `Self`
/// instead of being instance members.
///
/// To use a type conforming to this protocol, use ``Locked`` or
/// ``CustomLocked``.
///
/// This type is not part of the public interface of the testing library.
protocol Lockable: ~Copyable {
  /// Initialize an instance of this type at the given address.
  ///
  /// - Parameters:
  ///   - address: The address at which to initialize the new instance. On call,
  ///     this pointer's memory is uninitialized.
  static func initialize(at address: UnsafeMutablePointer<Self>)

  /// Deinitialize an instance of this type at the given address.
  ///
  /// - Parameters:
  ///   - address: The address at which to deinitialize an existing instance.
  static func deinitialize(at address: UnsafeMutablePointer<Self>)

  /// Acquire the lock and invoke a function while it is held.
  ///
  /// - Parameters:
  ///   - address: The address of the lock to acquire.
  ///   - body: A closure to invoke while the lock is held.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  static func withLock<R>(at address: UnsafeMutablePointer<Self>, _ body: @Sendable () throws -> sending R) rethrows -> sending R
}

#if SWT_TARGET_OS_APPLE && canImport(os)
/// On Apple platforms, we deploy to older OSes that don't have Swift 6's Mutex
/// type, so we need to rely on `os_unfair_lock` instead.
extension os_unfair_lock: Lockable {
  static func initialize(at address: UnsafeMutablePointer<Self>) {
    address.initialize(to: .init())
  }

  static func deinitialize(at address: UnsafeMutablePointer<Self>) {}

  static func withLock<R>(at address: UnsafeMutablePointer<Self>, _ body: @Sendable () throws -> sending R) rethrows -> sending R {
    os_unfair_lock_lock(address)
    defer {
      os_unfair_lock_unlock(address)
    }
    return try body()
  }
}
#endif

#if SWT_TARGET_OS_APPLE || os(Linux)
/// On Linux, we need to use a `pthread_cond_t` as part of the implementation of
/// exit tests, so we need to explicitly use `pthread_mutex_t` there. On Apple
/// platforms, if the `os` module is unavailable then we fall back to
/// `pthread_mutex_t`. On Apple platforms, we also fall back to it if exit tests
/// cannot use libdispatch to monitor for process termination.
extension pthread_mutex_t: Lockable {
  static func initialize(at address: UnsafeMutablePointer<Self>) {
    pthread_mutex_init(address, nil)
  }

  static func deinitialize(at address: UnsafeMutablePointer<Self>) {
    pthread_mutex_destroy(address)
  }

  static func withLock<R>(at address: UnsafeMutablePointer<Self>, _ body: @Sendable () throws -> sending R) rethrows -> sending R {
    pthread_mutex_lock(address)
    defer {
      pthread_mutex_unlock(address)
    }
    return try body()
  }
}
#endif

/// On non-Apple platforms, we can use the stdlib-supplied `Mutex`.
@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
extension Mutex<Void>: Lockable {
  static func initialize(at address: UnsafeMutablePointer<Self>) {
    address.initialize(to: .init(()))
  }

  static func deinitialize(at address: UnsafeMutablePointer<Self>) {
    address.deinitialize(count: 1)
  }

  static func withLock<R>(at address: UnsafeMutablePointer<Self>, _ body: @Sendable () throws -> sending R) rethrows -> sending R {
    try address.pointee.withLock { _ in
      try body()
    }
  }
}

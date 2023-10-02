//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_implementationOnly import TestingInternals
import _Backtracing

extension Backtrace {
  /// An entry in the error-mapping cache.
  private struct _ErrorMappingCacheEntry: Sendable {
    /// The error object (`SwiftError` or `NSError`) that was thrown.
    ///
    /// - Note: It is important that this value be of type `AnyObject`
    ///     rather than `Error`. `Error` is not a reference type, so weak
    ///     references to it cannot be constructed, and `Error`'s
    ///     existential containers do not have persistent heap addresses.
    ///
    /// - Bug: On Windows, the weak reference to this object triggers a
    ///   crash. To avoid said crash, we'll keep a strong reference to the
    ///   object (abandoning memory until the process exits.)
    ///   ([swift-#62985](https://github.com/apple/swift/issues/62985))
#if os(Windows)
    var errorObject: (any AnyObject & Sendable)?
#else
    weak var errorObject: (any AnyObject & Sendable)?
#endif

    /// The backtrace captured when `errorObject` was thrown.
    var backtrace: Backtrace
  }

  /// Storage for the error-mapping cache.
  ///
  /// Keys in this map are the raw addresses of the heap-allocated `SwiftError`
  /// and `NSError` boxes around thrown Swift errors. Addresses are, of course,
  /// dangerous to hold without also holding references to the relevant objects,
  /// but using `AnyObject` as a key would result in thrown errors never being
  /// deallocated.
  ///
  /// To ensure the keys remain valid, a _weak_ reference to the error object is
  /// held in the value. When an error is looked up by key, we check if the weak
  /// reference is valid. If it is, that means the error remains allocated at
  /// that address. If it is `nil`, then the error was deallocated (and the
  /// pointer we're holding is to a _different_ error that was allocated in the
  /// same location.)
  ///
  /// Access to this dictionary is guarded by a lock.
  @Locked
  private static var _errorMappingCache = [UnsafeRawPointer: _ErrorMappingCacheEntry]()

  /// The previous `swift_willThrow` handler, if any.
  @Locked
  private static var _oldWillThrowHandler: SWTWillThrowHandler?

  /// Handle a thrown error.
  ///
  /// - Parameters:
  ///   - errorAddress: The error that is about to be thrown. This pointer
  ///     refers to an instance of `SwiftError` or (on platforms with
  ///     Objective-C interop) an instance of `NSError`.
  @Sendable private static func _willThrow(_ errorAddress: UnsafeMutableRawPointer) {
    _oldWillThrowHandler?(errorAddress)

    let errorObject = unsafeBitCast(errorAddress, to: (any AnyObject & Sendable).self)
    guard let backtrace = try? Backtrace.capture() else {
      return
    }
    let newEntry = _ErrorMappingCacheEntry(errorObject: errorObject, backtrace: backtrace)

    Self.$_errorMappingCache.withLock { cache in
      let oldEntry = cache[errorAddress]
      if oldEntry?.errorObject == nil {
        // Either no entry yet, or its weak reference was zeroed.
        cache[errorAddress] = newEntry
      }
    }
  }

  /// The implementation of ``Backtrace/startCachingForThrownErrors()``, run
  /// only once.
  private static let _startCachingForThrownErrors: Void = {
    $_oldWillThrowHandler.withLock { oldWillThrowHandler in
      oldWillThrowHandler = swt_setWillThrowHandler { _willThrow($0) }
    }
  }()

  /// Configure the Swift runtime to allow capturing backtraces when errors are
  /// thrown.
  ///
  /// The testing library should call this function before running any
  /// developer-supplied code to ensure that thrown errors' backtraces are
  /// always captured.
  static func startCachingForThrownErrors() {
    _startCachingForThrownErrors
  }

  /// Flush stale entries from the error-mapping cache.
  ///
  /// Call this function periodically to ensure that errors do not continue to
  /// take up space in the cache after they have been deinitialized.
  static func flushThrownErrorCache() {
    Self.$_errorMappingCache.withLock { cache in
      cache = cache.filter { $0.value.errorObject != nil }
    }
  }

  /// Initialize an instance of this type with the previously-cached backtrace
  /// for a given error.
  ///
  /// - Parameters:
  ///   - error: The error for which a backtrace is needed.
  ///
  /// If no backtrace information is available for the specified error, this
  /// initializer returns `nil`. To start capturing backtraces, call
  /// ``Backtrace/startCachingForThrownErrors()``.
  ///
  /// - Note: Care must be taken to avoid unboxing and re-boxing `error`. This
  ///   initializer cannot be made an instance method or property of `Error`
  ///   because doing so will cause Swift-native errors to be unboxed into
  ///   existential containers with different addresses.
  @inline(never)
  init?(forFirstThrowOf error: any Error) {
    let errorAddress = unsafeBitCast(error, to: UnsafeRawPointer.self)
    let entry = Self.$_errorMappingCache.withLock { cache in
      cache[errorAddress]
    }
    if let entry, entry.errorObject != nil {
      // There was an entry and its weak reference is still valid.
      self = entry.backtrace
    } else {
      return nil
    }
  }
}

//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

/// A type representing a backtrace or stack trace.
@_spi(ForToolsIntegrationOnly)
public struct Backtrace: Sendable {
  /// A type describing an address in a backtrace.
  ///
  /// If a `nil` address is present in a backtrace, it is represented as `0`.
  public typealias Address = UInt64

  /// The addresses in this backtrace.
  public var addresses: [Address]

  /// Initialize an instance of this type with the specified addresses.
  ///
  /// - Parameters:
  ///   - addresses: The addresses in the backtrace.
  public init(addresses: some Sequence<Address>) {
    self.addresses = Array(addresses)
  }

  /// Initialize an instance of this type with the specified addresses.
  ///
  /// - Parameters:
  ///   - addresses: The addresses in the backtrace.
  ///
  /// The pointers in `addresses` are converted to instances of ``Address``. Any
  /// `nil` addresses are represented as `0`.
  public init(addresses: some Sequence<UnsafeRawPointer?>) {
    self.init(
      addresses: addresses.lazy
        .map(UInt.init(bitPattern:))
        .map(Address.init)
    )
  }

  /// Get the current backtrace.
  ///
  /// - Parameters:
  ///   - addressCount: The maximum number of addresses to include in the
  ///     backtrace. If the current call stack is larger than this value, the
  ///     resulting backtrace will be truncated to only the most recent
  ///     `addressCount` symbols.
  ///
  /// - Returns: A new instance of this type representing the backtrace of the
  ///   current thread. When supported by the operating system, the backtrace
  ///   continues across suspension points.
  ///
  /// The number of symbols captured in this backtrace is an implementation
  /// detail.
  public static func current(maximumAddressCount addressCount: Int = 128) -> Self {
    // NOTE: the exact argument/return types for backtrace() vary across
    // platforms, hence the use of .init() when calling it below.
    withUnsafeTemporaryAllocation(of: UnsafeMutableRawPointer?.self, capacity: addressCount) { addresses in
      var initializedCount = 0
#if SWT_TARGET_OS_APPLE
      if #available(_backtraceAsyncAPI, *) {
        initializedCount = backtrace_async(addresses.baseAddress!, addresses.count, nil)
      } else {
        initializedCount = .init(backtrace(addresses.baseAddress!, .init(addresses.count)))
      }
#elseif os(Android)
      initializedCount = addresses.withMemoryRebound(to: UnsafeMutableRawPointer.self) { addresses in
        .init(backtrace(addresses.baseAddress!, .init(addresses.count)))
      }
#elseif os(Linux)
      initializedCount = .init(backtrace(addresses.baseAddress!, .init(addresses.count)))
#elseif os(Windows)
      initializedCount = Int(RtlCaptureStackBackTrace(0, ULONG(addresses.count), addresses.baseAddress!, nil))
#elseif os(WASI)
      // SEE: https://github.com/WebAssembly/WASI/issues/159
      // SEE: https://github.com/swiftlang/swift/pull/31693
#else
#warning("Platform-specific implementation missing: backtraces unavailable")
#endif

      let endIndex = addresses.index(addresses.startIndex, offsetBy: initializedCount)
#if _pointerBitWidth(_64)
      // The width of a pointer equals the width of an `Address`, so we can just
      // bitcast the memory rather than mapping through UInt first.
      return addresses[..<endIndex].withMemoryRebound(to: Address.self) { addresses in
        Self(addresses: addresses)
      }
#else
      return addresses[..<endIndex].withMemoryRebound(to: UnsafeRawPointer?.self) { addresses in
        return Self(addresses: addresses)
      }
#endif
    }
  }
}

// MARK: - Equatable, Hashable

extension Backtrace: Equatable, Hashable {}

// MARK: - Codable

// Explicitly implement Codable support by encoding and decoding the addresses
// array directly. Doing this avoids an extra level of indirection in the
// encoded form of a backtrace.

extension Backtrace: Codable {
  public init(from decoder: any Decoder) throws {
    try self.init(addresses: [Address](from: decoder))
  }

  public func encode(to encoder: any Encoder) throws {
    try addresses.encode(to: encoder)
  }
}

// MARK: - Backtraces for thrown errors

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
    ///   ([swift-#62985](https://github.com/swiftlang/swift/issues/62985))
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
  /// Keys in this map are the object identifiers (i.e. the addresses) of the
  /// heap-allocated `SwiftError` and `NSError` boxes around thrown Swift
  /// errors. Addresses are, of course, dangerous to hold without also holding
  /// references to the relevant objects, but using `AnyObject` as a key would
  /// result in thrown errors never being deallocated.
  ///
  /// To ensure the keys remain valid, a _weak_ reference to the error object is
  /// held in the value. When an error is looked up by key, we check if the weak
  /// reference is valid. If it is, that means the error remains allocated at
  /// that address. If it is `nil`, then the error was deallocated (and the
  /// pointer we're holding is to a _different_ error that was allocated in the
  /// same location.)
  ///
  /// Access to this dictionary is guarded by a lock.
  private static let _errorMappingCache = Locked<[ObjectIdentifier: _ErrorMappingCacheEntry]>()

  /// The previous `swift_willThrow` handler, if any.
  private static let _oldWillThrowHandler = Locked<SWTWillThrowHandler?>()

  /// Handle a thrown error.
  ///
  /// - Parameters:
  ///   - errorAddress: The error that is about to be thrown. This pointer
  ///     refers to an instance of `SwiftError` or (on platforms with
  ///     Objective-C interop) an instance of `NSError`.
  ///   - backtrace: The backtrace from where the error was thrown.
  private static func _willThrow(_ errorAddress: UnsafeMutableRawPointer, from backtrace: Backtrace) {
    _oldWillThrowHandler.rawValue?(errorAddress)

    let errorObject = unsafeBitCast(errorAddress, to: (any AnyObject & Sendable).self)
    let errorID = ObjectIdentifier(errorObject)
    let newEntry = _ErrorMappingCacheEntry(errorObject: errorObject, backtrace: backtrace)

    _errorMappingCache.withLock { cache in
      let oldEntry = cache[errorID]
      if oldEntry?.errorObject == nil {
        // Either no entry yet, or its weak reference was zeroed.
        cache[errorID] = newEntry
      }
    }
  }

  /// The implementation of ``Backtrace/startCachingForThrownErrors()``, run
  /// only once.
  private static let _startCachingForThrownErrors: Void = {
    _oldWillThrowHandler.withLock { oldWillThrowHandler in
      oldWillThrowHandler = swt_setWillThrowHandler { errorAddress in
        let backtrace = Backtrace.current()
        _willThrow(errorAddress, from: backtrace)
      }
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
    _errorMappingCache.withLock { cache in
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
    let errorID = ObjectIdentifier(unsafeBitCast(error as any Error, to: AnyObject.self))
    let entry = Self._errorMappingCache.withLock { cache in
      cache[errorID]
    }
    if let entry, entry.errorObject != nil {
      // There was an entry and its weak reference is still valid.
      self = entry.backtrace
    } else {
      return nil
    }
  }
}

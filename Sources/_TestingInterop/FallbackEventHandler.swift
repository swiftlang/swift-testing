//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if compiler(>=6.3) && !SWT_NO_INTEROP
#if SWT_TARGET_OS_APPLE && !hasFeature(Embedded)
private import _TestingInternals
#else
private import Synchronization
#endif

/// `Atomic`-compatible storage for ``FallbackEventHandler``.
private final class _FallbackEventHandlerStorage: Sendable, RawRepresentable {
  let rawValue: FallbackEventHandler

  init(rawValue: FallbackEventHandler) {
    self.rawValue = rawValue
  }
}

/// The installed event handler.
#if SWT_TARGET_OS_APPLE && !hasFeature(Embedded)
private nonisolated(unsafe) let _fallbackEventHandler = {
  let result = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: 1)
  result.initialize(to: nil)
  return result
}()
#else
private let _fallbackEventHandler = AtomicLazyReference<_FallbackEventHandlerStorage>()
#endif

/// A type describing a fallback event handler that testing API can invoke as an
/// alternate method of reporting test events to the current test runner.
///
/// For example, an `XCTAssert` failure in the body of a Swift Testing test
/// cannot record issues directly with the Swift Testing runner. Instead, the
/// framework packages the assertion failure as a JSON `Event` and invokes this
/// handler to report the failure.
///
/// - Parameters:
///   - recordJSONSchemaVersionNumber: The JSON schema version used to encode
///     the event record.
///   - recordJSONBaseAddress: A pointer to the first byte of the encoded event.
///   - recordJSONByteCount: The size of the encoded event in bytes.
///   - reserved: Reserved for future use.
@usableFromInline
package typealias FallbackEventHandler = @Sendable @convention(c) (
  _ recordJSONSchemaVersionNumber: UnsafePointer<CChar>,
  _ recordJSONBaseAddress: UnsafeRawPointer,
  _ recordJSONByteCount: Int,
  _ reserved: UnsafeRawPointer?
) -> Void

/// Get the current fallback event handler.
///
/// - Returns: The currently-set handler function, if any.
#if compiler(>=6.3)
@c
#else
@_cdecl("_swift_testing_getFallbackEventHandler")
#endif
@usableFromInline
package func _swift_testing_getFallbackEventHandler() -> FallbackEventHandler? {
#if SWT_TARGET_OS_APPLE && !hasFeature(Embedded)
  guard let unmanaged = swt_atomicLoad(_fallbackEventHandler).map(Unmanaged<_FallbackEventHandlerStorage>.fromOpaque) else {
    return nil
  }
  return unmanaged.takeUnretainedValue().rawValue
#else
  // If we had a setter, this load would present a race condition because
  // another thread could store a new value in between the load and the call to
  // `takeUnretainedValue()`, resulting in a use-after-free on this thread. We
  // would need a full lock in order to avoid that problem. However, because we
  // instead have a one-time installation function, we can be sure that the
  // loaded value (if non-nil) will never be replaced with another value.
  return _fallbackEventHandler.load()?.rawValue
#endif
}

/// Set the current fallback event handler if one has not already been set.
///
/// - Parameters:
///   - handler: The handler function to set.
///
/// - Returns: Whether or not `handler` was installed.
///
/// The fallback event handler can only be installed once per process, typically
/// by the first testing library to run. If this function has already been
/// called and the handler set, it does not replace the previous handler.
#if compiler(>=6.3)
@c
#else
@_cdecl("_swift_testing_installFallbackEventHandler")
#endif
@usableFromInline
package func _swift_testing_installFallbackEventHandler(_ handler: FallbackEventHandler) -> CBool {
  var result = false

  let handler = _FallbackEventHandlerStorage(rawValue: handler)
#if SWT_TARGET_OS_APPLE && !hasFeature(Embedded)
  let unmanaged = Unmanaged.passRetained(handler)
  result = swt_atomicStoreIfZero(_fallbackEventHandler, unmanaged.toOpaque())
  if !result {
    unmanaged.release()
  }
#else
  let stored = _fallbackEventHandler.storeIfNil(handler)
  result = (handler === stored)
#endif

  return result
}
#endif

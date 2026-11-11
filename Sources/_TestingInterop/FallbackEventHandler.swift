//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_INTEROP
private import _TestingInternals
#if canImport(Synchronization)
private import Synchronization
#endif

/// `Atomic`-compatible storage for ``FallbackEventHandler``.
private final class _FallbackEventHandlerStorage: Sendable, RawRepresentable {
  let rawValue: SWTFallbackEventHandler

  init(rawValue: SWTFallbackEventHandler) {
    self.rawValue = rawValue
  }
}

/// The installed event handler.
#if os(anyAppleOS) && !hasFeature(Embedded)
private nonisolated(unsafe) let _fallbackEventHandler = {
  let result = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: 1)
  result.initialize(to: nil)
  return result
}()
#else
private let _fallbackEventHandler = AtomicLazyReference<_FallbackEventHandlerStorage>()
#endif

/// Get the current fallback event handler.
///
/// - Returns: The currently-set handler function, if any.
@c @implementation
package func _swift_testing_getFallbackEventHandler() -> SWTFallbackEventHandler? {
#if os(anyAppleOS) && !hasFeature(Embedded)
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
@c @implementation
package func _swift_testing_installFallbackEventHandler(_ handler: SWTFallbackEventHandler) -> CBool {
  var result = false

  let handler = _FallbackEventHandlerStorage(rawValue: handler)
#if os(anyAppleOS) && !hasFeature(Embedded)
  let unmanaged = Unmanaged.passRetained(handler)
  var expectedNil: UnsafeRawPointer?
  result = swt_atomicCompareExchange(_fallbackEventHandler, &expectedNil, unmanaged.toOpaque())
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

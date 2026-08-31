//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

#if !SWT_TARGET_OS_APPLE && canImport(Dispatch)
private import Dispatch
#endif

#if canImport(Synchronization)
private import Synchronization
#endif

#if !SWT_NO_SIGINFO
#if SWT_NO_LIBDISPATCH
#error("Platform-specific misconfiguration: support for SIGINFO handling requires support for libdispatch")
#endif
#endif

#if !SWT_NO_SIGINFO
/// The set of `SIGINFO` handlers configured in this process.
///
/// Generally, this array will contain no more than `1` element, but it can be
/// larger when testing the testing library or if multiple harnesses run in a
/// single process.
private let _all = Mutex<[Weak<SIGINFOHandler<Void>>]>()

/// The dispatch source that listens for `SIGINFO` (or the platform-specific
/// equivalent).
///
/// This declaration is annotated `nonisolated(unsafe)` because dispatch sources
/// do not conform to `Sendable` on non-Darwin targets.
private nonisolated(unsafe) let _siginfoSource = {
#if SWT_TARGET_OS_APPLE || os(FreeBSD) || os(OpenBSD)
  let source = DispatchSource.makeSignalSource(signal: SIGINFO, queue: .main)
#elseif os(Linux) || os(Android)
  // On Linux, SIGINFO is not defined, so we'll use SIGUSR1 for this purpose.
  let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
#elseif os(Windows)
  let source = DispatchSource.makeUserDataAddSource(queue: .main)
  SetConsoleCtrlHandler({ ctrlType in
    guard ctrlType == CTRL_BREAK_EVENT else {
      // Let the system handle it normally.
      return false
    }
    _siginfoSource.add(data: 1)
    return true
  }, true)
#else
#warning("Platform-specific implementation missing: SIGINFO handling unavailable")
  let source = DispatchSource.makeUserDataAddSource(queue: .main)
#endif

  source.setEventHandler {
    // Invoke all registered handler objects.
    for handler in _all.rawValue {
      handler.rawValue?()
    }
  }
  source.activate()
  return source
}()

/// A class whose instances represent `SIGINFO` handlers configured in this
/// process.
final class SIGINFOHandler<T>: Sendable {
  /// The handler function this instance represents.
  private let _handler: @Sendable () -> Void

  init(handlingWith handler: @escaping @Sendable () -> Void) where T == Void {
    // Ensure we're listening for signals by the time this object is ready.
    defer {
      _ = _siginfoSource
    }

    _handler = handler
    _all.withLock { all in
      all.append(Weak(self))
    }
  }

  deinit {
    _all.withLock { all in
      all.removeAll { $0.rawValue === self }
    }
  }

  fileprivate func callAsFunction() {
    _handler()
  }
}
#endif

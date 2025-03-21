//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

@_spi(Experimental)
#if SWT_NO_EXIT_TESTS
@available(*, unavailable, message: "Exit tests are not available on this platform.")
#endif
extension ExitTest {
  /// The possible conditions under which an exit test will complete.
  ///
  /// Values of this type are used to describe the conditions under which an
  /// exit test is expected to pass or fail by passing them to
  /// ``expect(exitsWith:observing:_:sourceLocation:performing:)`` or
  /// ``require(exitsWith:observing:_:sourceLocation:performing:)``.
  public struct Condition: Sendable {
    /// An enumeration describing the possible conditions for an exit test.
    private enum _Kind: Sendable, Equatable {
      /// The exit test must exit with a particular exit status.
      case statusAtExit(StatusAtExit)

      /// The exit test must exit with any failure.
      case failure
    }

    /// The kind of condition.
    private var _kind: _Kind
  }
}

// MARK: -

@_spi(Experimental)
#if SWT_NO_EXIT_TESTS
@available(*, unavailable, message: "Exit tests are not available on this platform.")
#endif
extension ExitTest.Condition {
  /// A condition that matches when a process terminates successfully with exit
  /// code `EXIT_SUCCESS`.
  public static var success: Self {
    // Strictly speaking, the C standard treats 0 as a successful exit code and
    // potentially distinct from EXIT_SUCCESS. To my knowledge, no modern
    // operating system defines EXIT_SUCCESS to any value other than 0, so the
    // distinction is academic.
#if !SWT_NO_EXIT_TESTS
    .exitCode(EXIT_SUCCESS)
#else
    fatalError("Unsupported")
#endif
  }

  /// A condition that matches when a process terminates abnormally with any
  /// exit code other than `EXIT_SUCCESS` or with any signal.
  public static var failure: Self {
    Self(_kind: .failure)
  }

  public init(_ statusAtExit: StatusAtExit) {
    self.init(_kind: .statusAtExit(statusAtExit))
  }

  /// Creates a condition that matches when a process terminates with a given
  /// exit code.
  ///
  /// - Parameters:
  ///   - exitCode: The exit code yielded by the process.
  ///
  /// The C programming language defines two [standard exit codes](https://en.cppreference.com/w/c/program/EXIT_status),
  /// `EXIT_SUCCESS` and `EXIT_FAILURE`. Platforms may additionally define their
  /// own non-standard exit codes:
  ///
  /// | Platform | Header |
  /// |-|-|
  /// | macOS | [`<stdlib.h>`](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/_Exit.3.html), [`<sysexits.h>`](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/sysexits.3.html) |
  /// | Linux | [`<stdlib.h>`](https://sourceware.org/glibc/manual/latest/html_node/Exit-Status.html), `<sysexits.h>` |
  /// | FreeBSD | [`<stdlib.h>`](https://man.freebsd.org/cgi/man.cgi?exit(3)), [`<sysexits.h>`](https://man.freebsd.org/cgi/man.cgi?sysexits(3)) |
  /// | OpenBSD | [`<stdlib.h>`](https://man.openbsd.org/exit.3), [`<sysexits.h>`](https://man.openbsd.org/sysexits.3) |
  /// | Windows | [`<stdlib.h>`](https://learn.microsoft.com/en-us/cpp/c-runtime-library/exit-success-exit-failure) |
  ///
  /// On macOS, FreeBSD, OpenBSD, and Windows, the full exit code reported by
  /// the process is yielded to the parent process. Linux and other POSIX-like
  /// systems may only reliably report the low unsigned 8 bits (0&ndash;255) of
  /// the exit code.
  public static func exitCode(_ exitCode: CInt) -> Self {
#if !SWT_NO_EXIT_TESTS
    Self(.exitCode(exitCode))
#else
    fatalError("Unsupported")
#endif
  }

  /// Creates a condition that matches when a process terminates with a given
  /// signal.
  ///
  /// - Parameters:
  ///   - signal: The signal that terminated the process.
  ///
  /// The C programming language defines a number of [standard signals](https://en.cppreference.com/w/c/program/SIG_types).
  /// Platforms may additionally define their own non-standard signal codes:
  ///
  /// | Platform | Header |
  /// |-|-|
  /// | macOS | [`<signal.h>`](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/signal.3.html) |
  /// | Linux | [`<signal.h>`](https://sourceware.org/glibc/manual/latest/html_node/Standard-Signals.html) |
  /// | FreeBSD | [`<signal.h>`](https://man.freebsd.org/cgi/man.cgi?signal(3)) |
  /// | OpenBSD | [`<signal.h>`](https://man.openbsd.org/signal.3) |
  /// | Windows | [`<signal.h>`](https://learn.microsoft.com/en-us/cpp/c-runtime-library/signal-constants) |
  public static func signal(_ signal: CInt) -> Self {
#if !SWT_NO_EXIT_TESTS
    Self(.signal(signal))
#else
    fatalError("Unsupported")
#endif
  }
}

// MARK: - Comparison

#if SWT_NO_EXIT_TESTS
@available(*, unavailable, message: "Exit tests are not available on this platform.")
#endif
extension ExitTest.Condition {
  /// Check whether or not an exit test condition matches a given exit status.
  ///
  /// - Parameters:
  ///   - statusAtExit: An exit status to compare against.
  ///
  /// - Returns: Whether or not `self` and `statusAtExit` represent the same
  ///   exit condition.
  ///
  /// Two exit test conditions can be compared; if either instance is equal to
  /// ``failure``, it will compare equal to any instance except ``success``.
  func isApproximatelyEqual(to statusAtExit: StatusAtExit) -> Bool {
    return switch (self._kind, statusAtExit) {
    case let (.failure, .exitCode(exitCode)):
      exitCode != EXIT_SUCCESS
    case (.failure, .signal):
      // All terminating signals are considered failures.
      true
    default:
      self._kind == .statusAtExit(statusAtExit)
    }
  }
}

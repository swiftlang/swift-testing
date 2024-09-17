//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

/// An enumeration describing possible conditions under which an exit test will
/// succeed or fail.
///
/// Values of this type can be passed to
/// ``expect(exitsWith:_:sourceLocation:performing:)`` or
/// ``require(exitsWith:_:sourceLocation:performing:)`` to configure which exit
/// statuses should be considered successful.
@_spi(Experimental)
#if SWT_NO_EXIT_TESTS
@available(*, unavailable, message: "Exit tests are not available on this platform.")
#endif
public enum ExitCondition: Sendable {
  /// The process terminated successfully with status `EXIT_SUCCESS`.
  public static var success: Self { .exitCode(EXIT_SUCCESS) }

  /// The process terminated abnormally with any status other than
  /// `EXIT_SUCCESS` or with any signal.
  case failure

  /// The process terminated with the given exit code.
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
  /// | Windows | [`<stdlib.h>`](https://learn.microsoft.com/en-us/cpp/c-runtime-library/exit-success-exit-failure) |
  ///
  /// On macOS, FreeBSD, and Windows, the full exit code reported by the process
  /// is yielded to the parent process. Linux and other POSIX-like systems may
  /// only reliably report the low unsigned 8 bits (0&ndash;255) of the exit
  /// code.
  case exitCode(_ exitCode: CInt)

  /// The process terminated with the given signal.
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
  /// | Windows | [`<signal.h>`](https://learn.microsoft.com/en-us/cpp/c-runtime-library/signal-constants) |
  ///
  /// On Windows, by default, the C runtime will terminate a process with exit
  /// code `-3` if a raised signal is not handled, exactly as if `exit(-3)` were
  /// called. As a result, this case is unavailable on that platform. Developers
  /// should use ``failure`` instead when testing signal handling on Windows.
#if os(Windows)
  @available(*, unavailable, message: "On Windows, use .failure instead.")
#endif
  case signal(_ signal: CInt)
}

// MARK: - Equatable

#if SWT_NO_EXIT_TESTS
@available(*, unavailable, message: "Exit tests are not available on this platform.")
#endif
extension ExitCondition {
  /// Check whether or not two values of this type are equal.
  ///
  /// - Parameters:
  ///   - lhs: One value to compare.
  ///   - rhs: Another value to compare.
  ///
  /// - Returns: Whether or not `lhs` and `rhs` are equal.
  ///
  /// Two instances of this type can be compared; if either instance is equal to
  /// ``failure``, it will compare equal to any instance except ``success``. To
  /// check if two instances are exactly equal, use the ``===(_:_:)`` operator:
  ///
  /// ```swift
  /// let lhs: ExitCondition = .failure
  /// let rhs: ExitCondition = .signal(SIGINT)
  /// print(lhs == rhs) // prints "true"
  /// print(lhs === rhs) // prints "false"
  /// ```
  ///
  /// This special behavior means that the ``==(_:_:)`` operator is not
  /// transitive, and does not satisfy the requirements of
  /// [`Equatable`](https://developer.apple.com/documentation/swift/equatable)
  /// or [`Hashable`](https://developer.apple.com/documentation/swift/hashable).
  ///
  /// For any values `a` and `b`, `a == b` implies that `a != b` is `false`.
  public static func ==(lhs: Self, rhs: Self) -> Bool {
#if SWT_NO_EXIT_TESTS
    fatalError("Unsupported")
#else
    return switch (lhs, rhs) {
    case let (.failure, .exitCode(exitCode)), let (.exitCode(exitCode), .failure):
      exitCode != EXIT_SUCCESS
#if !os(Windows)
    case (.failure, .signal), (.signal, .failure):
      // All terminating signals are considered failures.
      true
#endif
    default:
      lhs === rhs
    }
#endif
  }

  /// Check whether or not two values of this type are _not_ equal.
  ///
  /// - Parameters:
  ///   - lhs: One value to compare.
  ///   - rhs: Another value to compare.
  ///
  /// - Returns: Whether or not `lhs` and `rhs` are _not_ equal.
  ///
  /// Two instances of this type can be compared; if either instance is equal to
  /// ``failure``, it will compare equal to any instance except ``success``. To
  /// check if two instances are not exactly equal, use the ``!==(_:_:)``
  /// operator:
  ///
  /// ```swift
  /// let lhs: ExitCondition = .failure
  /// let rhs: ExitCondition = .signal(SIGINT)
  /// print(lhs != rhs) // prints "false"
  /// print(lhs !== rhs) // prints "true"
  /// ```
  ///
  /// This special behavior means that the ``!=(_:_:)`` operator is not
  /// transitive, and does not satisfy the requirements of
  /// [`Equatable`](https://developer.apple.com/documentation/swift/equatable)
  /// or [`Hashable`](https://developer.apple.com/documentation/swift/hashable).
  ///
  /// For any values `a` and `b`, `a == b` implies that `a != b` is `false`.
  public static func !=(lhs: Self, rhs: Self) -> Bool {
#if SWT_NO_EXIT_TESTS
    fatalError("Unsupported")
#else
    !(lhs == rhs)
#endif
  }

  /// Check whether or not two values of this type are identical.
  ///
  /// - Parameters:
  ///   - lhs: One value to compare.
  ///   - rhs: Another value to compare.
  ///
  /// - Returns: Whether or not `lhs` and `rhs` are identical.
  ///
  /// Two instances of this type can be compared; if either instance is equal to
  /// ``failure``, it will compare equal to any instance except ``success``. To
  /// check if two instances are exactly equal, use the ``===(_:_:)`` operator:
  ///
  /// ```swift
  /// let lhs: ExitCondition = .failure
  /// let rhs: ExitCondition = .signal(SIGINT)
  /// print(lhs == rhs) // prints "true"
  /// print(lhs === rhs) // prints "false"
  /// ```
  ///
  /// This special behavior means that the ``==(_:_:)`` operator is not
  /// transitive, and does not satisfy the requirements of
  /// [`Equatable`](https://developer.apple.com/documentation/swift/equatable)
  /// or [`Hashable`](https://developer.apple.com/documentation/swift/hashable).
  ///
  /// For any values `a` and `b`, `a === b` implies that `a !== b` is `false`.
  public static func ===(lhs: Self, rhs: Self) -> Bool {
    return switch (lhs, rhs) {
    case (.failure, .failure):
      true
    case let (.exitCode(lhs), .exitCode(rhs)):
      lhs == rhs
#if !os(Windows)
    case let (.signal(lhs), .signal(rhs)):
      lhs == rhs
#endif
    default:
      false
    }
  }

  /// Check whether or not two values of this type are _not_ identical.
  ///
  /// - Parameters:
  ///   - lhs: One value to compare.
  ///   - rhs: Another value to compare.
  ///
  /// - Returns: Whether or not `lhs` and `rhs` are _not_ identical.
  ///
  /// Two instances of this type can be compared; if either instance is equal to
  /// ``failure``, it will compare equal to any instance except ``success``. To
  /// check if two instances are not exactly equal, use the ``!==(_:_:)``
  /// operator:
  ///
  /// ```swift
  /// let lhs: ExitCondition = .failure
  /// let rhs: ExitCondition = .signal(SIGINT)
  /// print(lhs != rhs) // prints "false"
  /// print(lhs !== rhs) // prints "true"
  /// ```
  ///
  /// This special behavior means that the ``!=(_:_:)`` operator is not
  /// transitive, and does not satisfy the requirements of
  /// [`Equatable`](https://developer.apple.com/documentation/swift/equatable)
  /// or [`Hashable`](https://developer.apple.com/documentation/swift/hashable).
  ///
  /// For any values `a` and `b`, `a === b` implies that `a !== b` is `false`.
  public static func !==(lhs: Self, rhs: Self) -> Bool {
#if SWT_NO_EXIT_TESTS
    fatalError("Unsupported")
#else
    !(lhs === rhs)
#endif
  }
}

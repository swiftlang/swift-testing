//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_EMBEDDED_PLATFORM_H)
#define SWT_EMBEDDED_PLATFORM_H

#include "Defines.h"
#include "Includes.h"

SWT_ASSUME_NONNULL_BEGIN

/// This header includes declarations, but not definitions, of functions that
/// the testing library needs defined when built for Embedded Swift.
///
/// This header augments the set of declarations in the Swift runtime's Platform
/// Abstraction Layer, which can be found [here](https://github.com/swiftlang/swift/blob/main/stdlib/public/EmbeddedPlatform/swift/EmbeddedPlatform.h).

// MARK: - Console output

/// A type describing the capabilities of the current system's console output.
typedef struct swift_testing_console_capabilities_t {
  /// Whether or not the testing library should add ANSI escape codes to its
  /// console output.
  ///
  /// ## See Also
  ///
  /// - ``Event/ConsoleOutputRecorder/Options/useANSIEscapeCodes``
  unsigned int useANSIEscapeCodes : 1;

  /// The bit depth of ANSI colors supported by the current system's console.
  ///
  /// For example, black-and-white output has a bit depth of `1`, and true color
  /// output has a bit depth of `24`. Values of `1`, `4`, `8`, and `24` are
  /// supported. `0` is treated as equivalent to `1`, while all other values are
  /// rounded down to the nearest supported value.
  ///
  /// ## See Also
  ///
  /// - ``Event/ConsoleOutputRecorder/Options/ansiColorBitDepth``
  unsigned int ansiColorBitDepth : 5;
} swift_testing_console_capabilities_t;

/// Get the capabilities of the current system's console output.
///
/// - Parameters:
///   - outConsoleCapabilities: A pointer to memory large enough to hold an
///     instance of the ``swift_testing_console_capabilities_t`` structure. On
///     return, initialized to an instance of that type that describes the
///     capabilities of the console `_swift_testing_writeToConsole()` writes to.
///
/// - Returns: Whether or not `outConsoleCapabilities` was successfully
///   initialized. If it was not, the testing library assumes the system console
///   has none of the supported capabilities.
///
/// The testing library uses this function to determine what, if any,
/// capabilities the system console has.
///
/// - Important: The testing library may add additional fields to the
///   ``swift_testing_console_capabilities_t`` structure in the future. To
///   ensure source compatibility if the structure changes, be sure to
///   initialize the entire structure:
///
///   ```c
///   swift_testing_console_capabilities_t good = {};
///   swift_testing_console_capabilities_t bad;
///   ```
///
/// ### Reference implementations
///
/// This function can be implemented to simply return `false` if the current
/// system's console has none of the supported capabilities:
///
/// ```c
/// bool _swift_testing_getConsoleCapabilities(swift_testing_console_capabilities_t *outConsoleCapabilities) {
///   return false;
/// }
/// ```
///
/// ### Concurrency support
///
/// This function's implementation must be concurrency-safe unless the system is
/// single-threaded.
SWT_EXTERN SWT_NODISCARD bool _swift_testing_getConsoleCapabilities(swift_testing_console_capabilities_t *outConsoleCapabilities);

/// Writes a sequence of UTF-8 code points to the current system's console.
///
/// - Parameters:
///   - chars: The UTF-8 code points to write. It is not `NULL`-terminated.
///   - count: The number of UTF-8 code points at `chars`.
///
/// The testing library uses this function to write a _human-readable_
/// transcript of a test run. If possible, the implementation should write
/// output to the standard error stream. Calls to the Swift standard library's
/// `print()` function (or similar interfaces) do not use this function.
///
/// - Important: If the `_swift_testing_getConsoleCapabilities()` function
///   returns `true` and configures any of the supported capabilities, then
///   `chars` may contain ANSI escape codes or other metacontent in addition to
///   human-readable text. If the current system's console only supports plain
///   text, make sure your implementation of that function returns `false`.
///
/// ### Reference implementations
///
/// This function can be implemented as a call to `fwrite()`:
///
/// ```c
/// void _swift_testing_writeToConsole(const uint8_t *chars, size_t count) {
///   fwrite(chars, 1, count, stderr);
/// }
/// ```
///
/// If you want to redirect output from the testing library to the same place
/// that the standard library directs output from `print()`, you can call
/// `_swift_writeToStandardOutput()`:
///
/// ```c
/// extern void _swift_writeToStandardOutput(const unsigned char *, size_t);
///
/// void _swift_testing_writeToConsole(const uint8_t *chars, size_t count) {
///   _swift_writeToStandardOutput(chars, count);
/// }
/// ```
///
/// If the current system's console only supports ASCII output rather than
/// UTF-8, the implementation must take care to filter out or transform
/// non-ASCII code points:
///
/// ```c
/// void _swift_testing_writeToConsole(const uint8_t *chars, size_t count) {
///   flockfile(stderr); {
///     for (size_t i = 0; i < count; i++) {
///       char c = chars[i];
///       if (isascii(c)) {
///         fputc(c, stderr);
///       } else {
///         fputc('?', stderr);
///       }
///     }
///   } funlockfile(stderr);
/// }
/// ```
///
/// If your platform does not support any form of human-readable console output,
/// you can implement this function as a no-op.
///
/// ### Concurrency support
///
/// This function's implementation must be concurrency-safe unless the system is
/// single-threaded. In the reference example above, you can substitute
/// platform-specific equivalents for `flockfile()` and `funlockfile()` if
/// needed, or omit them entirely in single-threaded environments.
SWT_EXTERN void _swift_testing_writeToConsole(const uint8_t *chars, size_t count);

SWT_ASSUME_NONNULL_END
#endif

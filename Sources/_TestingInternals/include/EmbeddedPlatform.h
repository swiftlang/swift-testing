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

//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_STUBS_H)
#define SWT_STUBS_H

#include "Defines.h"
#include "Includes.h"

SWT_ASSUME_NONNULL_BEGIN

/// The C file handle type.
///
/// This typedef is necessary because `FILE *` may be imported into Swift as
/// either `OpaquePointer` or `UnsafeMutablePointer<FILE>` depending on the
/// current platform.
typedef FILE *SWT_FILE SWT_SWIFT_NAME(FILE);

/// Get the standard error stream.
///
/// This function is provided because directly accessing `stderr` from Swift
/// triggers concurrency warnings on some platforms about accessing shared
/// mutable state.
static inline SWT_FILE swt_stderr(void) SWT_SWIFT_NAME(getter:stderr()) {
  return stderr;
}

/// Get the current C error.
///
/// This function is provided because `errno` is a complex macro on some
/// platforms and cannot be imported directly into Swift.
static inline int swt_errno(void) SWT_SWIFT_NAME(getter:errno()) {
  return errno;
}

#if __has_include(<sys/stat.h>) && defined(S_ISFIFO)
/// Check if a given `mode_t` value indicates that a file is a pipe (FIFO.)
///
/// This function is exactly equivalent to the `S_ISFIFO()` macro. It is
/// necessary because the mode flag macros are not imported into Swift
/// consistently across platforms.
static inline bool swt_S_ISFIFO(mode_t mode) SWT_SWIFT_NAME(S_ISFIFO(_:)) {
  return S_ISFIFO(mode);
}
#endif

/// A type used by the testing library's own tests to validate how C
/// enumerations are presented in test output.
enum __attribute__((enum_extensibility(open))) SWTTestEnumeration {
  SWTTestEnumerationA, SWTTestEnumerationB
};

SWT_ASSUME_NONNULL_END

#endif

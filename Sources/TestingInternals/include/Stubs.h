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
typedef FILE *SWT_FILEHandle;

/// Get the standard error stream.
///
/// This function is provided because directly accessing `stderr` from Swift
/// triggers concurrency warnings on some platforms about accessing shared
/// mutable state.
static SWT_FILEHandle swt_stderr(void) {
  return stderr;
}

/// Set the standard error stream.
///
/// - Returns: The previous value of `stderr`.
///
/// This function is provided because directly accessing `stderr` from Swift
/// triggers concurrency warnings on some platforms about accessing shared
/// mutable state.
static SWT_FILEHandle _Null_unspecified swt_set_stderr(SWT_FILEHandle file) {
  _Atomic(SWT_FILEHandle) *atomicStderr = (_Atomic(SWT_FILEHandle) *)&stderr;
  return atomic_exchange_explicit(atomicStderr, file, memory_order_acq_rel);
}

/// Get the standard output stream.
///
/// This function is provided because directly accessing `stdout` from Swift
/// triggers concurrency warnings on some platforms about accessing shared
/// mutable state.
static SWT_FILEHandle swt_stdout(void) {
  return stdout;
}

/// Set the standard output stream.
///
/// - Returns: The previous value of `stdout`.
///
/// This function is provided because directly accessing `stdout` from Swift
/// triggers concurrency warnings on some platforms about accessing shared
/// mutable state.
static SWT_FILEHandle _Null_unspecified swt_set_stdout(SWT_FILEHandle file) {
  _Atomic(SWT_FILEHandle) *atomicStdout = (_Atomic(SWT_FILEHandle) *)&stdout;
  return atomic_exchange_explicit(atomicStdout, file, memory_order_acq_rel);
}

/// Get the current C error.
///
/// This function is provided because `errno` is a complex macro on some
/// platforms and cannot be imported directly into Swift.
static int swt_errno(void) {
  return errno;
}

#if __has_include(<sys/stat.h>) && defined(S_ISFIFO)
/// Check if a given `mode_t` value indicates that a file is a pipe (FIFO.)
///
/// This function is exactly equivalent to the `S_ISFIFO()` macro. It is
/// necessary because the mode flag macros are not imported into Swift
/// consistently across platforms.
static bool swt_S_ISFIFO(mode_t mode) {
  return S_ISFIFO(mode);
}
#endif

SWT_ASSUME_NONNULL_END

#endif

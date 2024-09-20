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

#if !SWT_NO_FILE_IO
/// The C file handle type.
///
/// This typedef is necessary because `FILE *` may be imported into Swift as
/// either `OpaquePointer` or `UnsafeMutablePointer<FILE>` depending on the
/// current platform.
typedef FILE *SWT_FILEHandle;

/// Get the standard output stream.
///
/// This function is provided because directly accessing `stdout` from Swift
/// triggers concurrency warnings on some platforms about accessing shared
/// mutable state.
static SWT_FILEHandle swt_stdout(void) {
  return stdout;
}

/// Get the standard error stream.
///
/// This function is provided because directly accessing `stderr` from Swift
/// triggers concurrency warnings on some platforms about accessing shared
/// mutable state.
static SWT_FILEHandle swt_stderr(void) {
  return stderr;
}
#endif

/// Get the current C error.
///
/// This function is provided because `errno` is a complex macro on some
/// platforms and cannot be imported directly into Swift.
static int swt_errno(void) {
  return errno;
}

#if !SWT_NO_FILE_IO
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
#endif

#if defined(__APPLE__) && !SWT_NO_MACH_PORTS
/// Get a Mach port representing the current task (process.)
///
/// This function is provided because `mach_task_self()` is a complex macro, but
/// directly accessing `mach_task_self_` from Swift triggers concurrency
/// warnings about accessing shared mutable state.
static mach_port_t swt_mach_task_self(void) {
  return mach_task_self();
}
#endif

#if defined(_WIN32)
/// Make a Win32 language ID.
///
/// This function is provided because `MAKELANGID()` is a complex macro and
/// cannot be imported directly into Swift.
static LANGID swt_MAKELANGID(int p, int s) {
  return MAKELANGID(p, s);
}

/// Get the value of `PROC_THREAD_ATTRIBUTE_HANDLE_LIST`.
///
/// This function is provided because `PROC_THREAD_ATTRIBUTE_HANDLE_LIST` is a
/// complex macro and cannot be imported directly into Swift.
static DWORD_PTR swt_PROC_THREAD_ATTRIBUTE_HANDLE_LIST(void) {
  return PROC_THREAD_ATTRIBUTE_HANDLE_LIST;
}
#endif

#if defined(__linux__) || defined(__FreeBSD__) || defined(__ANDROID__)
/// The environment block.
///
/// By POSIX convention, the environment block variable is declared in client
/// code rather than in a header.
SWT_EXTERN char *_Nullable *_Null_unspecified environ;

/// Get the environment block.
///
/// This function is provided because directly accessing `environ` from Swift
/// triggers concurrency warnings about accessing shared mutable state.
static char *_Nullable *_Null_unspecified swt_environ(void) {
  return environ;
}
#endif

#if defined(__linux__)
/// Set the name of the current thread.
///
/// This function declaration is provided because `pthread_setname_np()` is
/// only declared if `_GNU_SOURCE` is set, but setting it causes build errors
/// due to conflicts with Swift's Glibc module.
SWT_EXTERN int swt_pthread_setname_np(pthread_t thread, const char *name);
#endif

#if defined(__GLIBC__)
/// Close file descriptors above a given value when spawing a new process.
///
/// This symbol is provided because the underlying function was added to glibc
/// relatively recently and may not be available on all targets. Checking
/// `__GLIBC_PREREQ()` is insufficient because `_DEFAULT_SOURCE` may not be
/// defined at the point spawn.h is first included.
SWT_EXTERN int swt_posix_spawn_file_actions_addclosefrom_np(posix_spawn_file_actions_t *fileActions, int from);
#endif

#if !defined(__ANDROID__)
#if __has_include(<signal.h>) && defined(si_pid)
/// Get the value of the `si_pid` field of a `siginfo_t` structure.
///
/// This function is provided because `si_pid` is a complex macro on some
/// platforms and cannot be imported directly into Swift. It is renamed back to
/// `siginfo_t.si_pid` in Swift.
SWT_SWIFT_NAME(getter:siginfo_t.si_pid(self:))
static pid_t swt_siginfo_t_si_pid(const siginfo_t *siginfo) {
  return siginfo->si_pid;
}
#endif

#if __has_include(<signal.h>) && defined(si_status)
/// Get the value of the `si_status` field of a `siginfo_t` structure.
///
/// This function is provided because `si_status` is a complex macro on some
/// platforms and cannot be imported directly into Swift. It is renamed back to
/// `siginfo_t.si_status` in Swift.
SWT_SWIFT_NAME(getter:siginfo_t.si_status(self:))
static int swt_siginfo_t_si_status(const siginfo_t *siginfo) {
  return siginfo->si_status;
}
#endif
#endif

SWT_ASSUME_NONNULL_END

#endif

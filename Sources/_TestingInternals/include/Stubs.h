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

/// Mark a code path as unreachable.
///
/// This function is necessary because Swift does not have an equivalent of
/// `__builtin_unreachable()`.
__attribute__((always_inline, noreturn))
static inline void swt_unreachable(void) {
  __builtin_unreachable();
}

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

/// Get the first section in an NT image.
///
/// This function is provided because `IMAGE_FIRST_SECTION()` is a complex macro
/// and cannot be imported directly into Swift.
static const IMAGE_SECTION_HEADER *_Null_unspecified swt_IMAGE_FIRST_SECTION(const IMAGE_NT_HEADERS *ntHeader) {
  return IMAGE_FIRST_SECTION(ntHeader);
}
#endif

#if defined(__linux__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__ANDROID__)
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
/// Get the `FICLONE` `ioctl()` argument.
///
/// This function is provided because `FICLONE` is a complex macro and cannot be
/// imported directly into Swift.
static unsigned long swt_FICLONE(void) {
  return FICLONE;
}
#endif

#if defined(__FreeBSD__)
/// Get the `COPY_FILE_RANGE_CLONE` `copy_file_range()` flag.
///
/// This function is provided because `COPY_FILE_RANGE_CLONE` is not available
/// prior to FreeBSD 15.0. The caller should check `getosreldate()` before using
/// this flag.
static unsigned int swt_COPY_FILE_RANGE_CLONE(void) {
#if defined(COPY_FILE_RANGE_CLONE)
  return COPY_FILE_RANGE_CLONE;
#else
  // Compiled against an older unistd.h, but presumably running on FreeBSD 15.0
  // or newer. SEE: https://github.com/freebsd/freebsd-src/blob/main/sys/sys/unistd.h
  return 0x00800000;
#endif
}
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

/// Get the value of `EEXIST`.
///
/// This function is provided because `EEXIST` is a complex macro in wasi-libc
/// and cannot be imported directly into Swift.
static int swt_EEXIST(void) {
  return EEXIST;
}

#if defined(F_GETFD)
/// Call `fcntl(F_GETFD)`.
///
/// This function is provided because `fcntl()` is a variadic function and
/// cannot be imported directly into Swift.
static int swt_getfdflags(int fd) {
  return fcntl(fd, F_GETFD);
}
#endif

#if defined(F_SETFD)
/// Call `fcntl(F_SETFD)`.
///
/// This function is provided because `fcntl()` is a variadic function and
/// cannot be imported directly into Swift.
static int swt_setfdflags(int fd, int flags) {
  return fcntl(fd, F_SETFD, flags);
}
#endif

/// Get the name of the given exit code if one is available.
///
/// - Parameters:
///   - exitCode: An exit code.
///
/// - Returns: The name of `exitCode` if it is a known constant such as
///   `EXIT_FAILURE` or if a name for it is defined in `<sysexits.h>` and that
///   header is present at compile time. If no name is available for `exitCode`,
///   returns `NULL`.
///
/// - Note: The set of exit codes in `<sysexits.h>` is _de facto_ standardized
///   on platforms that include that header.
static const char *_Nullable swt_getExitCodeName(int exitCode) {
#define SWT_EXIT_CODE(NAME) NAME: return #NAME
  switch (exitCode) {
    case SWT_EXIT_CODE(EXIT_SUCCESS);
    case SWT_EXIT_CODE(EXIT_FAILURE);
#if __has_include(<sysexits.h>)
    case SWT_EXIT_CODE(EX_USAGE);
    case SWT_EXIT_CODE(EX_DATAERR);
    case SWT_EXIT_CODE(EX_NOINPUT);
    case SWT_EXIT_CODE(EX_NOUSER);
    case SWT_EXIT_CODE(EX_NOHOST);
    case SWT_EXIT_CODE(EX_UNAVAILABLE);
    case SWT_EXIT_CODE(EX_SOFTWARE);
    case SWT_EXIT_CODE(EX_OSERR);
    case SWT_EXIT_CODE(EX_OSFILE);
    case SWT_EXIT_CODE(EX_CANTCREAT);
    case SWT_EXIT_CODE(EX_IOERR);
    case SWT_EXIT_CODE(EX_TEMPFAIL);
    case SWT_EXIT_CODE(EX_PROTOCOL);
    case SWT_EXIT_CODE(EX_NOPERM);
    case SWT_EXIT_CODE(EX_CONFIG);
#endif
    default: return 0;
  }
#undef SWT_SYSEXIT_CODE
};

#if !SWT_NO_INTEROP

/// A type describing a fallback event handler that testing API can invoke as an
/// alternate method of reporting test events to the current test runner.
/// Shadows the type with the same name in _TestingInterop.
///
/// - Parameters:
///   - recordJSONSchemaVersionNumber: The JSON schema version used to encode
///     the event record.
///   - recordJSONBaseAddress: A pointer to the first byte of the encoded event.
///   - recordJSONByteCount: The size of the encoded event in bytes.
///   - reserved: Reserved for future use.
typedef void (* SWTFallbackEventHandler)(const char *recordJSONSchemaVersionNumber,
                                      const void *recordJSONBaseAddress,
                                      size_t recordJSONByteCount,
                                      const void *_Nullable reserved);

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
SWT_EXTERN bool _swift_testing_installFallbackEventHandler(SWTFallbackEventHandler);

/// Get the current fallback event handler.
/// Shadows the function with the same name in _TestingInterop.
///
/// - Returns: The currently-set handler function, if any.
SWT_EXTERN SWTFallbackEventHandler _Nullable _swift_testing_getFallbackEventHandler(void);

#endif

SWT_ASSUME_NONNULL_END

#endif

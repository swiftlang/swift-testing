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

// MARK: - Process configuration

/// A structure that stores the `argc` and `argv` values returned from
/// `_swift_testing_getArgcArgv()`.
typedef struct swift_testing_argc_argv_t {
  /// The number of arguments passed to the program.
  int argc;

  /// The arguments passed to the program.
  ///
  /// If the value of the ``argc`` field is less than or equal to `0`, the value
  /// of this field is ignored.
  char *_Nonnull *_Nullable argv SWT_NONISOLATED_UNSAFE;
} swift_testing_argc_argv_t SWT_SENDABLE;

/// Get the command-line arguments passed to the current process.
///
/// - Parameters:
///   - outArgcArgv: A pointer to memory large enough to hold an instance of the
///     ``swift_testing_argc_argv_t`` structure. On return, initialized to an
///     instance of that type. The array at `outArgcArgv->argv` and the strings
///     in it must remain valid for the lifetime of the process, and the caller
///     is not responsible for deallocating them.
///
/// - Returns: Whether or not `*outArgcArgv` was successfully initialized. If
///   the function returns `false`, the value of `*outArgcArgv` is undefined and
///   the testing library assumes no command-line arguments were passed to the
///   current process. If the function returns `true`, but `outArgcArgv->argc`
///   is less than or equal to `0`, the testing library acts as if this function
///   returned `false`.
///
/// The testing library uses this function to configure the current process
/// before running any tests. For more information about valid command-line
/// arguments, review the documentation for the `swift test` command.
///
/// ### Reference implementations
///
/// An implementation that has access to the command-line arguments of the
/// current process can provide them via this function:
///
/// ```c
/// extern int __argc;
/// extern char *__argv[];
///
/// bool _swift_testing_getArgcArgv(swift_testing_argc_argv_t *outArgcArgv) {
///   outArgcArgv->argc = __argc;
///   outArgcArgv->argv = __argv;
///   return true;
/// }
/// ```
///
/// If your platform does not support command-line arguments, or you cannot get
/// them at runtime, your implementation can return `false`:
///
/// ```c
/// bool _swift_testing_getArgcArgv(swift_testing_argc_argv_t *outArgcArgv) {
///   return false;
/// }
/// ```
///
/// ### Concurrency support
///
/// The testing library calls this function at most once during the lifetime of
/// a test process.
SWT_EXTERN SWT_NODISCARD bool _swift_testing_getArgcArgv(swift_testing_argc_argv_t *outArgcArgv);

/// Get the current process' environment block.
///
/// - Parameters:
///   - outEnvironment: A pointer to memory large enough to hold a C array of C
///     strings. On return, initialized to the environment block of the current
///     process, including a trailing `NULL` pointer as in the specification for
///     the POSIX `environ` variable. The array and the strings in it must
///     remain valid for the lifetime of the process, and the caller is not
///     responsible for deallocating them.
///
/// - Returns: Whether or not `*outEnvironment` was successfully initialized. If
///   the function returns `false`, the value of `*outEnvironment` is undefined
///   and the testing library assumes no environment variables exist in the
///   current process. If the function returns `true`, but `*outEnvironment` is
///   `NULL`, the testing library acts as if this function returned `false`.
///
/// The testing library uses this function to configure the current process
/// before running any tests. For more information about environment variables
/// that the testing library uses, review `EnvironmentVariables.md` in this
/// repository's `Documentation` folder.
///
/// ### Reference implementations
///
/// An implementation that has access to the environment variables set in the
/// current process can provide them via this function:
///
/// ```c
/// extern char **environ;
///
/// bool _swift_testing_getEnvironment(char ***outEnvironment) {
///   *outEnvironment = environ;
///   return true;
/// }
/// ```
///
/// If your platform does not support environment variables, or you cannot get
/// them at runtime, your implementation can return `false`:
///
/// ```c
/// bool _swift_testing_getEnvironment(char ***outEnvironment) {
///   return false;
/// }
/// ```
///
/// ### Concurrency support
///
/// The testing library calls this function at most once during the lifetime of
/// a test process. General thread safety issues with the POSIX `environ`
/// variable are [well-documented](https://www.austingroupbugs.net/view.php?id=188)
/// and are beyond the Platform Abstraction Layer's purview.
SWT_EXTERN SWT_NODISCARD bool _swift_testing_getEnvironment(char *_Nullable *_Nullable *_Nonnull outEnvironment);

// MARK: - System metadata

/// Get information about the embedded system on which (or for which) Swift
/// Testing has been built and is running.
///
/// - Parameters:
///   - outEmbeddedTargetInfo: A pointer to memory large enough to hold a C
///     string. On return, initialized to a UTF-8-encoded C string representing
///     some human-readable information identifying the current system. The
///     string must remain valid for the lifetime of the process, and the caller
///     is not responsible for deallocating it.
///
/// - Returns: Whether or not `*outEmbeddedTargetInfo` was successfully
///   initialized. If the function returns `false`, the value of
///   `*outEmbeddedTargetInfo` is undefined and the testing library assumes
///   there is no human-readable information available about the system. If the
///   function returns `true`, but `*outEmbeddedTargetInfo` is `NULL`, the
///   testing library acts as if this function returned `false`.
///
/// The testing library uses this function to describe the embedded system it
/// is running on. This information is used for diagnostic purposes only.
///
/// An implementation may choose to return a constant string, a string stored in
/// statically-allocated memory, or a string allocated at runtime. The resulting
/// string's meaning is implementation-defined, but where possible should
/// include useful information about the system's hardware, software, or other
/// defining characteristics.
///
/// ### Reference implementations
///
/// On POSIX-compliant targets, this function can be implemented as a call to
/// `uname()`:
///
/// ```c
/// bool _swift_testing_getEmbeddedTargetInfo(const char **outEmbeddedTargetInfo) {
///   static char *result = NULL;
///
///   if (!result) {
///     struct utsname name {};
///     if (0 == uname(&name)) {
///       (void)asprintf(&result, "%s (%s)", name.release, name.version);
///     }
///   }
///
///   *outEmbeddedTargetInfo = result;
///   return (result != NULL);
/// }
/// ```
///
/// If no meaningful information about the system is available, your
/// implementation can return `false`:
///
/// ```c
/// bool _swift_testing_getEmbeddedTargetInfo(const char **outEmbeddedTargetInfo) {
///   return false;
/// }
/// ```
///
/// ### Concurrency support
///
/// The testing library calls this function at most once during the lifetime of
/// a test process.
SWT_EXTERN bool _swift_testing_getEmbeddedTargetInfo(const char *_Nullable *_Nonnull outEmbeddedTargetInfo);

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
/// - Returns: Whether or not `*outConsoleCapabilities` was successfully
///   initialized. If the function returns `false`, the value of
///   `*outConsoleCapabilities` is undefined and the testing library assumes the
///   system console has none of the supported capabilities.
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

// MARK: - JSON output

/// Writes a JSON object.
///
/// - Parameters:
///   - json: The JSON bytes to write. It is not `NULL`-terminated.
///   - count: The number of bytes at `json`.
///   - terminator: If not `NULL`, a pointer to a single byte to write
///     immediately after writing `json`. This byte is not included in `json` to
///     avoid creating unnecessary copies of `json` in memory.
///
/// The testing library uses this function to write the JSON event stream on
/// targets that do not support file I/O. The destination is
/// implementation-defined. When built for non-Embedded Swift, or when built
/// with support for file I/O, the testing library writes JSON to files and
/// pipes specified by its caller in e.g. the command line arguments to
/// `swift test`.
///
/// ### Reference implementations
///
/// This function can be implemented with the following algorithm:
///
/// ```c
/// FILE *f = ...;
/// flockfile(f); {
///   fwrite(json, 1, count, f);
///   if (terminator) {
///     fputc(*terminator, f);
///   }
/// } funlockfile(f);
/// ```
///
/// If your platform does not support writing JSON or consuming it later, you
/// can implement this function as a no-op.
///
/// ### Concurrency support
///
/// This function's implementation must be concurrency-safe unless the system is
/// single-threaded. In the reference example above, you can substitute
/// platform-specific equivalents for `flockfile()` and `funlockfile()` if
/// needed, or omit them entirely in single-threaded environments.
SWT_EXTERN void _swift_testing_writeJSON(const uint8_t *json, size_t count, const uint8_t terminator[_Nullable 1]);

// MARK: - Test timing

/// A type representing a duration since some epoch.
typedef struct swift_testing_duration_t {
  /// The number of whole seconds since the epoch.
  uint32_t seconds;

  /// The number of nanoseconds, not counting whole seconds, since the epoch.
  ///
  /// The value of this field should be less than `1000000000`.
  uint32_t nanoseconds : 30;
} swift_testing_duration_t;

/// Get the amount of time that has passed since the system's epoch.
///
/// - Parameters:
///   - outDuration: On successful return, set to the amount of time that has
///     passed since the system's epoch.
///
/// - Returns: Whether or not `*outDuration` was successfully initialized. If
///   the function returns `false`, the value of `*outDuration` is undefined and
///   the testing library assumes a time of `0`.
///
/// The testing library uses this function to determine how long tests take to
/// run.
///
/// The system's epoch is typically the time when it booted or the time the
/// current process started. Avoid using the UNIX epoch (1970-01-01 00:00:00 UT)
/// or another realtime (wall-clock) epoch as the realtime clock can be adjusted
/// at runtime and may unexpectedly decrease. The epoch time itself does not
/// need to be representable in Swift.
///
/// The result of this function should have at least millisecond resolution. If
/// the platform does not support millisecond resolution or finer, the
/// implementation should still be as precise as possible. If the platform only
/// supports one-second resolution or coarser, the implementation must set
/// `outDuration->nanoseconds` to `0` before successfully returning.
///
/// - Note: Where possible, the implementation should use a suspending clock
///   rather than a continuous clock (that is, time the system spends asleep
///   should not, ideally, count toward the result of this function).
///
/// ### Reference implementations
///
/// On systems with the POSIX `clock_gettime()`, this function can be
/// implemented with the following algorithm:
///
/// ```c
/// bool _swift_testing_getDurationSinceSystemEpoch(swift_testing_duration_t *outDuration) {
///   struct timespec ts = {};
///   if (0 != clock_gettime(CLOCK_MONOTONIC, &ts)) {
///     return false;
///   }
///   outDuration->seconds = (uint32_t)ts.tv_sec;
///   outDuration->nanoseconds = (uint32_t)ts.tv_nsec;
///   return true;
/// }
/// ```
///
/// - Note: POSIX-compliant systems implement a variety of different clocks, and
///   they do not all implement `CLOCK_MONOTONIC`. Consult your platform's
///   documentation to determine the correct clock constant to pass to
///   `clock_gettime()`.
///
/// The implementation can also use system-specific interfaces to compute the
/// current time. For example, if the target is an Arduino board, you could use
/// the [`millis()`](https://docs.arduino.cc/language-reference/en/functions/time/millis/)
/// function:
///
/// ```c
/// bool _swift_testing_getDurationSinceSystemEpoch(swift_testing_duration_t *outDuration) {
///   unsigned long ms = millis();
///   outDuration->seconds = ms / 1000;
///   outDuration->nanoseconds = (ms % 1000) * 1000000; // ns per ms
///   return true;
/// }
/// ```
///
/// If the platform does not provide any high-level interfaces for computing the
/// current time, it may still provide lower-level interfaces for querying the
/// system counter, which can then be divided by the CPU's frequency to get an
/// approximate time value. The implementation of this logic is left as an
/// exercise for the reader.
///
/// This function can be implemented to simply return `false` if the platform
/// has no way to get the current time:
///
/// ```c
/// bool _swift_testing_getDurationSinceSystemEpoch(swift_testing_duration_t *outDuration) {
///   return false;
/// }
/// ```
///
/// ### Concurrency support
///
/// This function's implementation must be concurrency-safe unless the system is
/// single-threaded.
SWT_EXTERN SWT_NODISCARD bool _swift_testing_getDurationSinceSystemEpoch(swift_testing_duration_t *outDuration);

SWT_ASSUME_NONNULL_END
#endif

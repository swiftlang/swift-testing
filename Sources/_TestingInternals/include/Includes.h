//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_INCLUDES_H)
#define SWT_INCLUDES_H

/// This header includes other headers (either those from the C standard library
/// or platform-specific headers) that are used by the testing library.
///
/// Include any headers here from the C standard library that are needed by the
/// testing library. Because the C standard library cannot be directly imported
/// into Swift without introducing a module dependency (and because the name of
/// that module varies on a platform-by-platform basis), we instead include C
/// standard library headers _à la carte_. Symbols from these headers are then
/// imported into Swift when a Swift file imports the `_TestingInternals` module.
///
/// Also include any platform-specific headers here that are needed by the
/// testing library.
///
/// - Note: Avoid including headers that aren't actually used.

#include <errno.h>
/// Guard against including `signal.h` on WASI. The `signal.h` header file
/// itself is available in wasi-libc, but it's just a stub that doesn't actually
/// do anything. And also including it requires a special macro definition
/// (`_WASI_EMULATED_SIGNAL`) and it causes compilation errors without the macro.
#if __has_include(<signal.h>) && !defined(__wasi__)
#include <signal.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#if defined(__APPLE__) && __has_include(<dispatch/dispatch.h>)
#include <dispatch/dispatch.h>
#endif

#if __has_include(<unistd.h>)
#include <unistd.h>
#endif

#if __has_include(<fcntl.h>)
#include <fcntl.h>
#elif __has_include(<sys/fcntl.h>)
#include <sys/fcntl.h>
#endif

#if __has_include(<sys/stat.h>)
#include <sys/stat.h>
#endif

#if __has_include(<sys/sysctl.h>) && !defined(__linux__)
#include <sys/sysctl.h>
#endif

#if __has_include(<sys/wait.h>)
#include <sys/wait.h>
#endif

#if __has_include(<sys/utsname.h>)
#include <sys/utsname.h>
#endif

#if __has_include(<execinfo.h>)
#include <execinfo.h>
#endif

#if __has_include(<pthread.h>)
#include <pthread.h>
#endif

#if __has_include(<pty.h>)
#include <pty.h>
#endif

#if __has_include(<pwd.h>)
#include <pwd.h>
#endif

#if __has_include(<limits.h>)
#include <limits.h>
#endif

#if __has_include(<spawn.h>)
#include <spawn.h>
#endif

#if __has_include(<crt_externs.h>)
#include <crt_externs.h>
#endif

#if __has_include(<wasi/libc-environ.h>)
#include <wasi/libc-environ.h>
#endif

#if __has_include(<libgen.h>)
#include <libgen.h>
#endif

#if __has_include(<dlfcn.h>)
#include <dlfcn.h>
#endif

#if __has_include(<sysexits.h>)
#include <sysexits.h>
#endif

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>
#include <Psapi.h>
#endif

#if defined(__ANDROID__)
#pragma clang module import posix_filesystem.linux_stat
#include <sys/system_properties.h>
#endif

#endif

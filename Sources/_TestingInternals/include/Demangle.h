//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_DEMANGLE_H)
#define SWT_DEMANGLE_H

#include "Defines.h"
#include "Includes.h"

#include <stdbool.h>

SWT_ASSUME_NONNULL_BEGIN

/// Demangle a Swift symbol name.
///
/// - Parameters:
///   - mangledName: A pointer to the mangled symbol name to demangle.
///   - mangledNameLength: The length of `mangledName` in bytes, not including
///     any trailing null byte.
///   - outputBuffer: Unused by the testing library. Pass `nullptr`.
///   - outputBufferSize: Unused by the testing library. Pass `nullptr`.
///   - flags: Unused by the testing library. Pass `0`.
///
/// - Returns: The demangled form of `mangledName`, or `nullptr` if demangling
///   failed. The caller is responsible for freeing this string with `free()`
///   when done.
SWT_IMPORT_FROM_STDLIB char *_Nullable swift_demangle(
  const char *mangledName,
  size_t mangledNameLength,
  char *_Nullable outputBuffer,
  size_t *_Nullable outputBufferSize,
  uint32_t flags
);

#if defined(_WIN32)
/// Configure the environment to allow calling into the Debug Help library.
///
/// - Parameters:
///   - body: A function to invoke. A process handle valid for use with Debug
///     Help functions is passed in, or `nullptr` if the Debug Help library
///     could not be initialized.
///   - context: An arbitrary pointer to pass to `body`.
///
/// On Windows, the Debug Help library (DbgHelp.lib) is not thread-safe. All
/// calls into it from the Swift runtime and stdlib should route through this
/// function.
SWT_IMPORT_FROM_STDLIB void _swift_win32_withDbgHelpLibrary(
  void (* body)(HANDLE _Nullable hProcess, void *_Null_unspecified context),
  void *_Null_unspecified context
);
#endif

SWT_ASSUME_NONNULL_END

#endif

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

/// Attempt to demangle the given symbol name.
///
/// - Parameters:
///   - symbolName: The symbol name to demangle.
///
/// - Returns: The demangled form of `symbolName`, or `nullptr` if it could not
///   be demangled.
///
/// On Windows, this function must only be called from within a call to
/// `_swift_win32_withDbgHelpLibrary()`. Note that Swift symbol demangling may
/// internally use `operator new`.
SWT_EXTERN char *_Nullable swt_copyDemangledSymbolName(const char *symbolName);

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

//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_VERSIONS_H)
#define SWT_VERSIONS_H

#include "Defines.h"
#include "Includes.h"

SWT_ASSUME_NONNULL_BEGIN

/// Get the human-readable version of the testing library.
///
/// - Returns: A human-readable string describing the version of the testing
///   library, or `nullptr` if no version information is available. This
///   string's value and format may vary between platforms, releases, or any
///   other conditions. Do not attempt to parse it.
SWT_EXTERN const char *_Nullable swt_getTestingLibraryVersion(void);

/// Get the LLVM target triple used to build the testing library.
///
/// - Returns: A string containing the LLVM target triple used to build the
///   testing library, or `nullptr` if that information is not available.
SWT_EXTERN const char *_Nullable swt_getTargetTriple(void);

#if defined(__wasi__)
/// Get the version of the C standard library and runtime used by WASI, if
/// available.
///
/// This function is provided because `WASI_SDK_VERSION` may or may not be
/// defined and may or may not be a complex macro.
///
/// For more information about the `WASI_SDK_VERSION` macro, see
/// [wasi-libc-#490](https://github.com/WebAssembly/wasi-libc/issues/490).
static const char *_Nullable swt_getWASIVersion(void) {
#if defined(WASI_SDK_VERSION)
  return WASI_SDK_VERSION;
#else
  return 0;
#endif
}
#endif

SWT_ASSUME_NONNULL_END

#endif

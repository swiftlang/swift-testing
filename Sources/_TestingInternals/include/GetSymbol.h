//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_GETSYMBOL_H)
#define SWT_GETSYMBOL_H

#include "Defines.h"

#if !defined(SWT_NO_DYNAMIC_LINKING)
SWT_ASSUME_NONNULL_BEGIN

/// Use the platform's dynamic loader to get a function in the current process
/// at runtime.
///
/// - Parameters:
///   - handle: A platform-specific handle to the image in which to look for
///     `symbolName`. If `nullptr`, the function may be found in any image
///     loaded into the current process.
///   - symbolName: The name of the function to find.
///
/// - Returns: A pointer to the specified function, or `nullptr` if it could not
///   be found.
///
/// Callers looking for a function declared in a specific image should pass a
/// handle acquired from `dlopen()` as the `handle` argument. On Windows, pass
/// the result of `GetModuleHandleW()` or an equivalent function.
///
/// When `handle` is `nullptr`, this function is equivalent to
/// `dlsym(RTLD_DEFAULT, symbolName)`. This function must be implemented in C++
/// instead of Swift because `RTLD_DEFAULT` is a complex macro on some platforms
/// and cannot be imported directly into Swift. As well, `RTLD_DEFAULT` is only
/// defined on Linux when `_GNU_SOURCE` is defined.
///
/// On Windows, there is no equivalent of `RTLD_DEFAULT`. It is simulated by
/// calling `EnumProcessModules()` and iterating over the returned handles
/// looking for one containing the given function.
SWT_EXTERN void *_Nullable swt_getFunctionWithName(void *_Nullable handle, const char *symbolName);

SWT_ASSUME_NONNULL_END
#endif

#endif

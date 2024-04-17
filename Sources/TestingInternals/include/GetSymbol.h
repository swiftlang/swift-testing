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
///     `symbolName`. If `nullptr`, `RTLD_DEFAULT` (on platforms with `dlsym()`)
///     is used.
///   - symbolName: The name of the function to find.
///
/// - Returns: A pointer to the specified function, or `nullptr` if it could not
///   be found.
SWT_EXTERN void *_Nullable swt_getFunctionWithName(void *_Nullable handle, const char *symbolName);

SWT_ASSUME_NONNULL_END
#endif

#endif

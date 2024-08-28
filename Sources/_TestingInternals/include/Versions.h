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

SWT_ASSUME_NONNULL_BEGIN

/// Get the human-readable version of the testing library.
///
/// - Returns: A human-readable string describing the version of the testing
///   library, or `nullptr` if no version information is available. This
///   string's value and format may vary between platforms, releases, or any
///   other conditions. Do not attempt to parse it.
SWT_EXTERN const char *_Nullable swt_getTestingLibraryVersion(void);

SWT_ASSUME_NONNULL_END

#endif

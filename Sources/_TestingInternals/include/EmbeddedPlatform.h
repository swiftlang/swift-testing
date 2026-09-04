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

/// This header includes declarations, but not definitions, of functions that
/// the testing library needs defined when built for Embedded Swift.
///
/// This header augments the set of declarations in the Swift runtime's Platform
/// Abstraction Layer, which can be found [here](https://github.com/swiftlang/swift/blob/main/stdlib/public/EmbeddedPlatform/swift/EmbeddedPlatform.h).

/// Get the bounds of the test content section in the current program.
///
/// - Parameters:
///   - outBegin: On return, the address of the first byte of the test content
///     section.
///   - outEnd: On return, the address of the first byte _after_ the end of the
///     test content section.
///
/// - Returns: Whether or not `outBegin` and `outEnd` were set. If this function
///   returns `false`, there are no tests in the current program for the testing
///   library to run.
///
/// The testing library uses this function to determine the bounds of the test
/// content section in the current image when built for Embedded Swift against
/// a platform that does not use the Mach-O, ELF, or Wasm image format.
SWT_EXTERN bool _swift_testing_getTestSectionBounds(
  const void *_Nullable *_Nonnull outBegin,
  const void *_Nullable *_Nonnull outEnd
);
#endif

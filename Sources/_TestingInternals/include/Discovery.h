//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_DISCOVERY_H)
#define SWT_DISCOVERY_H

#include "Defines.h"

#include <stdbool.h>
#include <stddef.h>

SWT_ASSUME_NONNULL_BEGIN

/// The type of callback called by `swt_enumerateTypes()`.
///
/// - Parameters:
///   - typeMetadata: A type metadata pointer that can be bitcast to `Any.Type`.
///   - stop: A pointer to a boolean variable indicating whether type
///     enumeration should stop after the function returns. Set `*stop` to
///     `true` to stop type enumeration.
///   - context: An arbitrary pointer passed by the caller to
///     `swt_enumerateTypes()`.
typedef void (* SWTTypeEnumerator)(void *typeMetadata, bool *stop, void *_Null_unspecified context);

/// Enumerate all types known to Swift found in the current process.
///
/// - Parameters:
///   - nameSubstring: A string which the names of matching classes all contain.
///   - sectionStart: The start of the section to examine.
///   - sectionLength: The length, in bytes, of the section to examine.
///   - context: An arbitrary pointer to pass to `body`.
///   - body: A function to invoke, once per matching type.
SWT_EXTERN void swt_enumerateTypesWithNamesContaining(
  const char *nameSubstring,
  const void *sectionStart,
  size_t sectionLength,
  void *_Null_unspecified context,
  SWTTypeEnumerator body
) SWT_SWIFT_NAME(swt_enumerateTypes(withNamesContaining:inSectionStartingAt:byteCount:_:_:));

SWT_ASSUME_NONNULL_END

#endif

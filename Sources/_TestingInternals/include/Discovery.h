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
#include "Includes.h"

SWT_ASSUME_NONNULL_BEGIN

/// The type of callback called by `swt_enumerateTypes()`.
///
/// - Parameters:
///   - imageAddress: A pointer to the start of the image. This value is _not_
///     equal to the value returned from `dlopen()`. On platforms that do not
///     support dynamic loading (and so do not have loadable images), this
///     argument is unspecified.
///   - typeMetadata: A type metadata pointer that can be bitcast to `Any.Type`.
///   - stop: A pointer to a boolean variable indicating whether type
///     enumeration should stop after the function returns. Set `*stop` to
///     `true` to stop type enumeration.
///   - context: An arbitrary pointer passed by the caller to
///     `swt_enumerateTypes()`.
typedef void (* SWTTypeEnumerator)(const void *_Null_unspecified imageAddress, void *typeMetadata, bool *stop, void *_Null_unspecified context);

/// Enumerate all types known to Swift found in the current process.
///
/// - Parameters:
///   - nameSubstring: A string which the names of matching classes all contain.
///   - context: An arbitrary pointer to pass to `body`.
///   - body: A function to invoke, once per matching type.
SWT_EXTERN void swt_enumerateTypesWithNamesContaining(
  const char *nameSubstring,
  void *_Null_unspecified context,
  SWTTypeEnumerator body
) SWT_SWIFT_NAME(swt_enumerateTypes(withNamesContaining:_:_:));

SWT_ASSUME_NONNULL_END

#endif

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

#pragma mark - Test content records

/// The type of a test content accessor.
///
/// - Parameters:
///   - outValue: On successful return, initialized to the value of the
///     represented test content record.
///   - hint: A hint value whose type and meaning depend on the type of test
///     record being accessed.
///
/// - Returns: Whether or not the test record was initialized at `outValue`. If
///   this function returns `true`, the caller is responsible for deinitializing
///   the memory at `outValue` when done.
typedef bool (* SWTTestContentAccessor)(void *outValue, const void *_Null_unspecified hint);

/// Resign an accessor function from a test content record.
///
/// - Parameters:
///   - accessor: The accessor function to resign.
///
/// - Returns: A resigned copy of `accessor` on platforms that use pointer
///   authentication, and an exact copy of `accessor` elsewhere.
///
/// - Bug: This C function is needed because Apple's pointer authentication
///   intrinsics are not available in Swift. ([141465242](rdar://141465242))
SWT_SWIFT_NAME(swt_resign(_:))
static SWTTestContentAccessor swt_resignTestContentAccessor(SWTTestContentAccessor accessor) {
#if defined(__APPLE__) && __has_include(<ptrauth.h>)
  accessor = ptrauth_strip(accessor, ptrauth_key_function_pointer);
  accessor = ptrauth_sign_unauthenticated(accessor, ptrauth_key_function_pointer, 0);
#endif
  return accessor;
}

#if defined(__ELF__) && defined(__swift__)
/// A function exported by the Swift runtime that enumerates all metadata
/// sections loaded into the current process.
///
/// This function is needed on ELF-based platforms because they do not preserve
/// section information that we can discover at runtime.
SWT_IMPORT_FROM_STDLIB void swift_enumerateAllMetadataSections(
  bool (* body)(const void *sections, void *context),
  void *context
);
#endif

#pragma mark - Statically-linked section bounds

/// The bounds of the test content section statically linked into the image
/// containing Swift Testing.
///
/// - Note: This symbol is _declared_, but not _defined_, on platforms with
///   dynamic linking because the `SWT_NO_DYNAMIC_LINKING` C++ macro (not the
///   Swift compiler conditional of the same name) is not consistently declared
///   when Swift files import the `_TestingInternals` C++ module.
SWT_EXTERN const void *_Nonnull const SWTTestContentSectionBounds[2];

#pragma mark - Legacy test discovery

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

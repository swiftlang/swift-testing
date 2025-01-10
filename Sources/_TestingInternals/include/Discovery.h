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

#if defined(SWT_NO_DYNAMIC_LINKING)
#pragma mark - Statically-linked section bounds

/// The bounds of the test content section statically linked into the image
/// containing Swift Testing.
SWT_EXTERN const void *_Nonnull const SWTTestContentSectionBounds[2];

#if !defined(SWT_NO_LEGACY_TEST_DISCOVERY)
/// The bounds of the type metadata section statically linked into the image
/// containing Swift Testing.
SWT_EXTERN const void *_Nonnull const SWTTypeMetadataSectionBounds[2];
#endif
#endif

#pragma mark - Legacy test discovery

/// Copy all types known to Swift found in the given type metadata section with
/// a name containing the given substring.
///
/// - Parameters:
///   - sectionBegin: The address of the first byte of the Swift type metadata
///     section.
///   - sectionSize: The size, in bytes, of the Swift type metadata section.
///   - nameSubstring: A string which the names of matching classes all contain.
///   - outCount: On return, the number of type metadata pointers returned.
///
/// - Returns: A pointer to an array of type metadata pointers. The caller is
///   responsible for freeing this memory with `free()` when done.
SWT_EXTERN void *_Nonnull *_Nonnull swt_copyTypesWithNamesContaining(
  const void *sectionBegin,
  size_t sectionSize,
  const char *nameSubstring,
  size_t *outCount
) SWT_SWIFT_NAME(swt_copyTypes(in:_:withNamesContaining:count:));

SWT_ASSUME_NONNULL_END

#endif

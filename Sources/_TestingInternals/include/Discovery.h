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

/// The bounds of the type metadata section statically linked into the image
/// containing Swift Testing.
///
/// - Note: This symbol is _declared_, but not _defined_, on platforms with
///   dynamic linking because the `SWT_NO_DYNAMIC_LINKING` C++ macro (not the
///   Swift compiler conditional of the same name) is not consistently declared
///   when Swift files import the `_TestingInternals` C++ module.
SWT_EXTERN const void *_Nonnull const SWTTypeMetadataSectionBounds[2];

#pragma mark - Legacy test discovery

/// The size, in bytes, of a Swift type metadata record.
SWT_EXTERN const size_t SWTTypeMetadataRecordByteCount;

/// Get the type represented by the type metadata record at the given address if
/// its name contains the given string.
///
/// - Parameters:
///   - recordAddress: The address of the Swift type metadata record.
///   - nameSubstring: A string which the names of matching types contain.
///
/// - Returns: A Swift metatype (as `const void *`) or `nullptr` if it wasn't a
///   usable type metadata record or its name did not contain `nameSubstring`.
SWT_EXTERN const void *_Nullable swt_getTypeFromTypeMetadataRecord(
  const void *recordAddress,
  const char *nameSubstring
) SWT_SWIFT_NAME(swt_getType(fromTypeMetadataRecord:ifNameContains:));

SWT_ASSUME_NONNULL_END

#endif

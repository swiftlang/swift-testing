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

#if defined(__ELF__) && defined(__swift__)
#pragma mark - ELF image enumeration

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

#if defined(SWT_NO_DYNAMIC_LINKING)
/// A type describing the bounds of a section that has been statically linked
/// into the image containing Swift Testing.
typedef const void *_Nonnull SWTStaticallyLinkedSectionBounds[2];

/// The bounds of sections that have been statically linked into the same image
/// as the testing library (and which the testing library needs to reference).
SWT_EXTERN const SWTStaticallyLinkedSectionBounds *const SWTAllStaticallyLinkedSectionBounds;
#endif

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

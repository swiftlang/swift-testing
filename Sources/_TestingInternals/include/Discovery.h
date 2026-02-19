//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
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

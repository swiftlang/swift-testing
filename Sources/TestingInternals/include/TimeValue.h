//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_TIMEVALUE_H)
#define SWT_TIMEVALUE_H

#include "Defines.h"
#include "Includes.h"

SWT_ASSUME_NONNULL_BEGIN

/// A type representing a 128-bit integer.
///
/// This type is necessary because `_BitInt(128)`, `__int128_t`, and `__int128`
/// are not available in Swift. Assuming [SE-0425](https://github.com/apple/swift-evolution/blob/main/proposals/0425-int128.md)
/// is approved, the testing library can adopt the 128-bit type it introduces.
///
/// At this time, the testing library does not generally perform much 128-bit
/// math. This type is used solely by ``TimeValue``.
typedef struct SWTInt128 {
  /// The high 64 bits of the integer including the sign bit.
  int64_t hi;

  /// The low 64 bits of the integer.
  uint64_t lo;
} SWTInt128;

/// The number of attoseconds in one second.
static const uint64_t SWT_ASEC_PER_SEC = UINT64_C(1000000000000000000);

/// Convert a ``TimeValue`` to a 128-bit integer.
///
/// This function is necessary because Swift does not (yet) have its own 128-bit
/// integer type.
static SWTInt128 swt_timeValueToInt128(int64_t seconds, int64_t attoseconds) {
  _BitInt(128) tv128 = attoseconds + ((_BitInt(128))seconds * SWT_ASEC_PER_SEC);
  return (SWTInt128){ tv128 >> 64, tv128 };
}

/// Convert a 128-bit integer to a ``TimeValue``.
///
/// This function is necessary because Swift does not (yet) have its own 128-bit
/// integer type.
static void swt_int128ToTimeValue(SWTInt128 attoseconds, int64_t *outSeconds, int64_t *outAttoseconds) {
  _BitInt(128) tv128 = ((_BitInt(128))attoseconds.hi << 64) | attoseconds.lo;
  *outSeconds = tv128 / SWT_ASEC_PER_SEC;
  *outAttoseconds = tv128 % SWT_ASEC_PER_SEC;
}

SWT_ASSUME_NONNULL_END

#endif

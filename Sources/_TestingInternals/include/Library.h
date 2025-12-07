//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_LIBRARY_H)
#define SWT_LIBRARY_H

#include "Defines.h"
#include "Includes.h"

SWT_ASSUME_NONNULL_BEGIN

/*
  fileprivate typealias EntryPoint = @Sendable @convention(c) (
    _ configurationJSON: UnsafeRawPointer,
    _ configurationJSONByteCount: Int,
    _ reserved: UInt,
    _ context: UnsafeRawPointer,
    _ recordJSONHandler: EntryPointRecordJSONHandler,
    _ completionHandler: EntryPointCompletionHandler
  ) -> Void

  fileprivate typealias EntryPointRecordJSONHandler = @Sendable @convention(c) (
    _ recordJSON: UnsafeRawPointer,
    _ recordJSONByteCount: Int,
    _ reserved: UInt,
    _ context: UnsafeRawPointer
  ) -> Void

  fileprivate typealias EntryPointCompletionHandler = @Sendable @convention(c) (
    _ exitCode: CInt,
    _ reserved: UInt,
    _ context: UnsafeRawPointer
  ) -> Void
*/

typedef void (* SWT_SENDABLE SWTLibraryEntryPointRecordJSONHandler)(
  const void *recordJSON,
  size_t recordJSONByteCount,
  uintptr_t reserved,
  const void *_Null_unspecified context
);

typedef void (* SWT_SENDABLE SWTLibraryEntryPointCompletionHandler)(
  int exitCode,
  uintptr_t reserved,
  const void *_Null_unspecified context
);

typedef void (* SWT_SENDABLE SWTLibraryEntryPoint)(
  const void *configurationJSON,
  size_t configurationJSONByteCount,
  uintptr_t reserved,
  const void *_Null_unspecified context,
  SWTLibraryEntryPointRecordJSONHandler SWT_SENDABLE recordJSONHandler,
  SWTLibraryEntryPointCompletionHandler SWT_SENDABLE completionHandler
);

/// A C type that provides the in-memory layout of the ``Library`` Swift type.
typedef struct SWTLibrary {
  const char *name;
  SWTLibraryEntryPoint SWT_SENDABLE entryPoint;
  uintptr_t reserved[6];
} SWTLibrary;

/// Get the name of the testing library (i.e. `"Swift Testing"`) as a
/// statically-allocated C string.
static inline const char *swt_getSwiftTestingLibraryName(void) {
  return "Swift Testing";
}

SWT_ASSUME_NONNULL_END

#endif

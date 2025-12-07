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

typedef void (* SWTLibraryEntryPointRecordJSONHandler)(
  const void *recordJSON,
  size_t recordJSONByteCount,
  uintptr_t reserved,
  const void *_Null_unspecified context
);

typedef void (* SWTLibraryEntryPointCompletionHandler)(
  const void *resultJSON,
  size_t resultJSONByteCount,
  uintptr_t reserved,
  const void *_Null_unspecified context
);

typedef void (* SWTLibraryEntryPoint)(
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
  const char *canonicalHint; // TODO: better name
  SWTLibraryEntryPoint entryPoint;
  uintptr_t reserved[5];
} SWTLibrary;

SWT_ASSUME_NONNULL_END

#endif

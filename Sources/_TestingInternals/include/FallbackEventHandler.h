//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_NO_INTEROP)
#include "Defines.h"
#include "Includes.h"

SWT_ASSUME_NONNULL_BEGIN

/// A type describing a fallback event handler that testing API can invoke as an
/// alternate method of reporting test events to the current test runner.
/// Shadows the type with the same name in _TestingInterop.
///
/// - Parameters:
///   - recordJSONSchemaVersionNumber: The JSON schema version used to encode
///     the event record.
///   - recordJSONBaseAddress: A pointer to the first byte of the encoded event.
///   - recordJSONByteCount: The size of the encoded event in bytes.
///   - reserved: Reserved for future use.
typedef void (* SWTFallbackEventHandler)(const char *recordJSONSchemaVersionNumber,
                                      const void *recordJSONBaseAddress,
                                      size_t recordJSONByteCount,
                                      const void *_Nullable reserved);

/// Set the current fallback event handler if one has not already been set.
///
/// - Parameters:
///   - handler: The handler function to set.
///
/// - Returns: Whether or not `handler` was installed.
///
/// The fallback event handler can only be installed once per process, typically
/// by the first testing library to run. If this function has already been
/// called and the handler set, it does not replace the previous handler.
SWT_EXTERN bool _swift_testing_installFallbackEventHandler(SWTFallbackEventHandler handler);

/// Get the current fallback event handler.
/// Shadows the function with the same name in _TestingInterop.
///
/// - Returns: The currently-set handler function, if any.
SWT_EXTERN SWTFallbackEventHandler _Nullable _swift_testing_getFallbackEventHandler(void);

SWT_ASSUME_NONNULL_END

#endif

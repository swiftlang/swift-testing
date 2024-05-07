//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_WILLTHROW_H)
#define SWT_WILLTHROW_H

#include "Defines.h"

SWT_ASSUME_NONNULL_BEGIN

/// The type of handler that is called by `swift_willThrow()`.
///
/// - Parameters:
///   - error: The error that is about to be thrown. This pointer refers to an
///     instance of `SwiftError` or (on platforms with Objective-C interop) an
///     instance of `NSError`.
typedef void (* SWT_SENDABLE SWTWillThrowHandler)(void *error);

/// Set the callback function that fires when an instance of `Swift.Error` is
/// thrown.
///
/// - Parameters:
///   - handler: The handler function to set, or `nil` to clear the handler
///     function.
///
/// - Returns: The previously-set handler function, if any.
///
/// This function sets the global `_swift_willThrow()` variable in the Swift
/// runtime, which is reserved for use by the testing framework. If another
/// testing framework such as XCTest has already set a handler, it is returned.
///
/// ## See Also
///
/// ``SWTWillThrowHandler``
SWT_EXTERN SWTWillThrowHandler SWT_SENDABLE _Nullable swt_setWillThrowHandler(SWTWillThrowHandler SWT_SENDABLE _Nullable handler);

SWT_ASSUME_NONNULL_END

#endif

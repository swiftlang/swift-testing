//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import TestingInternals

/// A type representing an error from a C function such as `fopen()`.
///
/// This type is necessary because Foundation's `POSIXError` is not available in
/// all contexts.
///
/// This type is not part of the public interface of the testing library.
struct CError: Error, RawRepresentable {
  var rawValue: CInt
}

// MARK: - CustomStringConvertible

/// Get a string describing a C error code.
///
/// - Parameters:
///   - errorCode: The error code to describe.
///
/// - Returns: A Swift string equal to the result of `strerror()`.
func strerror(_ errorCode: CInt) -> String {
  String(unsafeUninitializedCapacity: 1024) { buffer in
#if SWT_TARGET_OS_APPLE || os(Linux)
    _ = strerror_r(errorCode, buffer.baseAddress!, buffer.count)
#elseif os(Windows)
    _ = strerror_s(buffer.baseAddress!, buffer.count, errorCode)
#else
    guard let stringValue = strerror(errorCode) else {
      return 0
    }
    strncpy(buffer.baseAddress!, stringValue, buffer.count)
#endif
    return strnlen(buffer.baseAddress!, buffer.count)
  }
}

extension CError: CustomStringConvertible {
  var description: String {
    strerror(rawValue)
  }
}

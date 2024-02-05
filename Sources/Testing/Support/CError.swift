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
/// - Returns: A Swift string equal to the result of `strerror()` from the C
///   standard library.
func strerror(_ errorCode: CInt) -> String {
#if os(Windows)
  String(unsafeUninitializedCapacity: 1024) { buffer in
    _ = strerror_s(buffer.baseAddress!, buffer.count, errorCode)
    return strnlen(buffer.baseAddress!, buffer.count)
  }
#else
  String(cString: TestingInternals.strerror(errorCode))
#endif
}

extension CError: CustomStringConvertible {
  var description: String {
    strerror(rawValue)
  }
}

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

extension CError: CustomStringConvertible {
  var description: String {
    String(cString: strerror(rawValue))
  }
}

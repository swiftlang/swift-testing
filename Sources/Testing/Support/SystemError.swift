//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing an error in the testing library or its underlying
/// infrastructure.
///
/// When an error of this type is thrown and caught by the testing library, it
/// is recorded as an issue of kind ``Issue/Kind/system`` rather than
/// ``Issue/Kind/errorCaught(_:)``.
///
/// This type is not part of the public interface of the testing library.
/// External callers should generally record issues by throwing their own errors
/// or by calling ``Issue/record(_:sourceLocation:)``.
struct SystemError: Error, CustomStringConvertible {
  var description: String
}

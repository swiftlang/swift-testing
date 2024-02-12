//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Result {
  /// Handle this instance as if it were returned from a call to `#expect()`.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  public func __expected() {}

  /// Handle this instance as if it were returned from a call to `#require()`.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  public func __required() throws -> Success {
    /// `get()` is current broken in the Swift standard library, so switch
    /// manually to work around the problem. ([122797397](rdar://122797397))
    switch self {
    case let .success(result):
      return result
    case let .failure(error):
      throw error
    }
  }
}

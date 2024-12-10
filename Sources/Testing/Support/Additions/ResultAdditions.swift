//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Result where Success: ~Copyable {
  /// Handle this instance as if it were returned from a call to `#expect()`.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @inlinable public borrowing func __expected() where Success == Void {}

  /// Handle this instance as if it were returned from a call to `#require()`.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @inlinable public consuming func __required() throws -> Success {
    try get()
  }
}

// MARK: - Optional success values

extension Result {
  /// Handle this instance as if it were returned from a call to `#expect()`.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @inlinable public func __expected<T>() -> Success where Success == T? {
    try? get()
  }

  /// Handle this instance as if it were returned from a call to `#require()`.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @inlinable public func __required<T>() throws -> T where Success == T? {
    // TODO: handle edge case where the value is nil (see #780)
    try get()!
  }
}

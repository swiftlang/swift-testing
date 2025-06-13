//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Result where Success: ~Escapable {
  /// Handle this instance as if it were returned from a call to `#expect()`.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @inlinable public func __expected() where Success == Void {}

  /// Handle this instance as if it were returned from a call to `#require()`.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @lifetime(copy self)
  @inlinable public func __required() throws -> Success {
    try get()
  }
}

// MARK: - Optional success values

extension Result {
  /// Handle this instance as if it were returned from a call to `#expect()`.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @discardableResult @inlinable public func __expected<T>() -> Success where Success == T? {
    try? get()
  }

  /// Handle this instance as if it were returned from a call to `#require()`.
  ///
  /// This overload of `__require()` assumes that the result cannot actually be
  /// `nil` on success. The optionality is part of our ABI contract for the
  /// `__check()` function family so that we can support uninhabited types and
  /// "soft" failures.
  ///
  /// If the value really is `nil` (e.g. we're dealing with `Never`), the
  /// testing library throws an error representing an issue of kind
  /// ``Issue/Kind-swift.enum/apiMisused``.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @discardableResult public func __required<T>() throws -> T where Success == T? {
    guard let result = try get() else {
      throw APIMisuseError(description: "Could not unwrap 'nil' value of type Optional<\(T.self)>. Consider using #expect() instead of #require() here.")
    }
    return result
  }
}

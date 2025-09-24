//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_IMPLICIT_POINTER_CASTING
// MARK: String-to-C-string handling and implicit pointer conversions

extension __ExpectationContext {
  /// Capture a pointer for use if the expectation currently being evaluated
  /// fails.
  ///
  /// - Parameters:
  ///   - value: The value to pass through.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///
  /// - Returns: `value`, verbatim.
  ///
  /// This overload of `callAsFunction()` is used when a pointer is passed to
  /// allow for the correct handling of implicit pointer conversion after it
  /// returns.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @inlinable public func callAsFunction<P>(_ value: borrowing P, _ id: __ExpressionID) -> P where P: _Pointer {
    captureValue(value, id)
  }

  /// Capture a string for use if the expectation currently being evaluated
  /// fails.
  ///
  /// - Parameters:
  ///   - value: The value to pass through.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///
  /// - Returns: `value`, verbatim.
  ///
  /// This overload of `callAsFunction()` is used when a string is passed to
  /// allow for the correct handling of implicit C string conversion after it
  /// returns. For more information about implicit type conversions performed by
  /// the Swift compiler, see [here](https://developer.apple.com/documentation/swift/calling-functions-with-pointer-parameters#Pass-a-Constant-Pointer-as-a-Parameter).
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @inlinable public func callAsFunction(_ value: borrowing String, _ id: __ExpressionID) -> String {
    captureValue(value, id)
  }

  /// Capture an array for use if the expectation currently being evaluated
  /// fails.
  ///
  /// - Parameters:
  ///   - value: The value to pass through.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///
  /// - Returns: `value`, verbatim.
  ///
  /// This overload of `callAsFunction()` is used when an array is passed to
  /// allow for the correct handling of implicit C array conversion after it
  /// returns. For more information about implicit type conversions performed by
  /// the Swift compiler, see [here](https://developer.apple.com/documentation/swift/calling-functions-with-pointer-parameters#Pass-a-Constant-Pointer-as-a-Parameter).
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @inlinable public func callAsFunction<E>(_ value: borrowing Array<E>, _ id: __ExpressionID) -> Array<E> {
    captureValue(value, id)
  }

  /// Capture an optional value for use if the expectation currently being
  /// evaluated fails.
  ///
  /// - Parameters:
  ///   - value: The value to pass through.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///
  /// - Returns: `value`, verbatim.
  ///
  /// This overload of `callAsFunction()` is used when an optional value is
  /// passed to allow for the correct handling of various implicit conversions.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @_disfavoredOverload
  @inlinable public func callAsFunction<T>(_ value: borrowing T?, _ id: __ExpressionID) -> T? {
    captureValue(value, id)
  }
}
#endif

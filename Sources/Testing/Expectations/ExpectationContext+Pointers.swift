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
  /// A protocol describing types that can be implicitly cast to C strings or
  /// pointers when passed to C functions.
  ///
  /// This protocol helps the compiler disambiguate string values when they need
  /// to be implicitly cast to C strings or other pointer types.
  ///
  /// - Warning: This protocol is used to implement the `#expect()` and
  ///   `#require()` macros. Do not use it directly. Do not add conformances to
  ///   this protocol outside of the testing library.
  public protocol __ImplicitlyPointerConvertible {
    /// The concrete type of the resulting pointer when an instance of this type
    /// is implicitly cast.
    associatedtype __ImplicitPointerConversionResult

    /// Perform an implicit cast of this instance to its corresponding pointer
    /// type.
    ///
    /// - Parameters:
    /// 	- expectationContext: The expectation context that needs to cast this
    ///   	instance.
    ///
    /// - Returns: A copy of this instance, cast to a pointer.
    ///
    ///  The implementation of this method should register the resulting pointer
    ///  with `expectationContext` so that it is not leaked.
    ///
    /// - Warning: This function is used to implement the `#expect()` and
    ///   `#require()` macros. Do not call it directly.
    func __implicitlyCast(for expectationContext: inout __ExpectationContext) -> __ImplicitPointerConversionResult
  }

  /// Capture information about a value for use if the expectation currently
  /// being evaluated fails.
  ///
  /// - Parameters:
  ///   - value: The value to pass through.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///
  /// - Returns: `value`, cast to a C string.
  ///
  /// This overload of `callAsFunction(_:_:)` helps the compiler disambiguate
  /// string values when they need to be implicitly cast to C strings or other
  /// pointer types.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @_disfavoredOverload
  @inlinable public mutating func callAsFunction<S>(_ value: S, _ id: __ExpressionID) -> S.__ImplicitPointerConversionResult where S: __ImplicitlyPointerConvertible {
    captureValue(value, id).__implicitlyCast(for: &self)
  }

  /// Capture information about a value for use if the expectation currently
  /// being evaluated fails.
  ///
  /// - Parameters:
  ///   - value: The value to pass through.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///
  /// - Returns: `value`, verbatim.
  ///
  /// This overload of `callAsFunction(_:_:)` helps the compiler disambiguate
  /// string values when they do _not_ need to be implicitly cast to C strings
  /// or other pointer types. Without this overload, all instances of conforming
  /// types end up being cast to pointers before being compared (etc.), which
  /// produces incorrect results.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @inlinable public mutating func callAsFunction<S>(_ value: S, _ id: __ExpressionID) -> S where S: __ImplicitlyPointerConvertible {
    captureValue(value, id)
  }

  /// Convert some pointer to another pointer type and capture information about
  /// it for use if the expectation currently being evaluated fails.
  ///
  /// - Parameters:
  ///   - value: The pointer to cast.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///
  /// - Returns: `value`, cast to another type of pointer.
  ///
  /// This overload of `callAsFunction(_:_:)` handles the implicit conversions
  /// between various pointer types that are normally provided by the compiler.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @inlinable public mutating func callAsFunction<P1, P2>(_ value: P1?, _ id: __ExpressionID) -> P2! where P1: _Pointer, P2: _Pointer {
    captureValue(value, id).flatMap { value in
      P2(bitPattern: Int(bitPattern: value))
    }
  }
}

extension __ExpectationContext.__ImplicitlyPointerConvertible where Self: Collection {
  public func __implicitlyCast(for expectationContext: inout __ExpectationContext) -> UnsafeMutablePointer<Element> {
    // If `count` is 0, Swift may opt not to allocate any storage, and we'll
    // crash dereferencing the base address.
    let count = Swift.max(1, count)

    // Create a copy of this collection. Note we don't automatically add a null
    // character at the end (for C strings) because that could mask bugs in test
    // code that should automatically be adding them.
    let resultPointer = UnsafeMutableBufferPointer<Element>.allocate(capacity: count)
    let initializedEnd = resultPointer.initialize(fromContentsOf: self)

    expectationContext.callWhenDeinitializing {
      resultPointer[..<initializedEnd].deinitialize()
      resultPointer.deallocate()
    }

    return resultPointer.baseAddress!
  }
}

extension String: __ExpectationContext.__ImplicitlyPointerConvertible {
  @inlinable public func __implicitlyCast(for expectationContext: inout __ExpectationContext) -> UnsafeMutablePointer<CChar> {
    utf8CString.__implicitlyCast(for: &expectationContext)
  }
}

extension Optional: __ExpectationContext.__ImplicitlyPointerConvertible where Wrapped: __ExpectationContext.__ImplicitlyPointerConvertible {
  public func __implicitlyCast(for expectationContext: inout __ExpectationContext) -> Wrapped.__ImplicitPointerConversionResult? {
    flatMap { $0.__implicitlyCast(for: &expectationContext) }
  }
}

extension Array: __ExpectationContext.__ImplicitlyPointerConvertible {}
extension ContiguousArray: __ExpectationContext.__ImplicitlyPointerConvertible {}
#endif

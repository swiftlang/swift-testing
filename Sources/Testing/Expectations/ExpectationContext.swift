//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

/// A type representing the context within a call to the `#expect()` and
/// `#require()` macros.
///
/// When the compiler expands a call to either of these macros, it creates a
/// local instance of this type that is used to collect information about the
/// various subexpressions of the macro's condition argument. The nature of the
/// collected information is subject to change over time.
///
/// - Warning: This type is used to implement the `#expect()` and `#require()`
///   macros. Do not use it directly.
public struct __ExpectationContext: ~Copyable {
  /// The source code of any captured expressions.
  var sourceCode: [__ExpressionID: String]

  /// The runtime values of any captured expressions.
  ///
  /// The values in this dictionary are generally gathered at runtime as
  /// subexpressions are evaluated. Not all expressions captured at compile time
  /// will have runtime values: notably, if an operand to a short-circuiting
  /// binary operator like `&&` is not evaluated, the corresponding expression
  /// will not be assigned a runtime value.
  var runtimeValues: [__ExpressionID: () -> Expression.Value?]

  /// Computed differences between the operands or arguments of expressions.
  ///
  /// The values in this dictionary are gathered at runtime as subexpressions
  /// are evaluated, much like ``runtimeValues``.
  var differences: [__ExpressionID: () -> CollectionDifference<Any>?]

  init(
    sourceCode: [__ExpressionID: String] = [:],
    runtimeValues: [__ExpressionID: () -> Expression.Value?] = [:],
    differences: [__ExpressionID: () -> CollectionDifference<Any>?] = [:]
  ) {
    self.sourceCode = sourceCode
    self.runtimeValues = runtimeValues
    self.differences = differences
  }

  /// Collapse the given expression graph into one or more expressions with
  /// nested subexpressions.
  ///
  /// - Parameters:
  ///   - expressionGraph: The expression graph to collapse.
  ///   - depth: How deep into the expression graph this call is. The first call
  ///     has a depth of `0`.
  ///
  /// - Returns: An array of expressions under the root node of
  ///   `expressionGraph`. The expression at the root of the graph is not
  ///   included in the result.
  private borrowing func _squashExpressionGraph(_ expressionGraph: Graph<UInt32, __Expression?>, depth: Int) -> [__Expression] {
    var result = [__Expression]()

    let childGraphs = expressionGraph.children.sorted { $0.key < $1.key }
    for (_, childGraph) in childGraphs {
      let subexpressions = _squashExpressionGraph(childGraph, depth: depth + 1)
      if var subexpression = childGraph.value {
        subexpression.subexpressions += subexpressions
        result.append(subexpression)
      } else {
        // Hoist subexpressions of the child graph as there was no expression
        // recorded for it.
        result += subexpressions
      }
    }

    return result
  }

  /// Perform whatever final work is needed on this instance in order to produce
  /// an instance of `__Expression` corresponding to the condition expression
  /// being evaluated.
  ///
  /// - Parameters:
  ///   - successfully: Whether or not the expectation is "successful" (i.e. its
  ///     condition expression evaluates to `true`). If the expectation failed,
  ///     more diagnostic information is gathered including the runtime values
  ///     of any subexpressions of the condition expression.
  ///
  /// - Returns: An expression value representing the condition expression that
  ///   was evaluated.
  ///
  /// - Bug: This function should ideally be `consuming`, but because it is used
  ///   in a `lazy var` declaration, the compiler currently disallows it.
  borrowing func finalize(successfully: Bool) -> __Expression {
    // Construct a graph containing the source code for all the subexpressions
    // we've captured during evaluation.
    var expressionGraph = Graph<UInt32, __Expression?>()
    for (id, sourceCode) in sourceCode {
      let keyPath = id.keyPath
      expressionGraph.insertValue(__Expression(sourceCode), at: keyPath)
    }

    // If the expectation failed, insert any captured runtime values into the
    // graph alongside the source code.
    if !successfully {
      for (id, runtimeValue) in runtimeValues {
        let keyPath = id.keyPath
        if var expression = expressionGraph[keyPath], let runtimeValue = runtimeValue() {
          expression.runtimeValue = runtimeValue
          expressionGraph[keyPath] = expression
        }
      }

      for (id, difference) in differences {
        let keyPath = id.keyPath
        if var expression = expressionGraph[keyPath], let difference = difference() {
          let differenceDescription = Self._description(of: difference)
          expression.differenceDescription = differenceDescription
          expressionGraph[keyPath] = expression
        }
      }
    }

    // Flatten the expression graph.
    var subexpressions = _squashExpressionGraph(expressionGraph, depth: 0)
    var expression = if let rootExpression = expressionGraph.value {
      // We had a root expression and can add all reported subexpressions to it.
      // This should be the common case.
      rootExpression
    } else if subexpressions.count == 1 {
      // We had no root expression, but we did have a single reported
      // subexpression that can serve as our root.
      subexpressions.removeFirst()
    } else {
      // We could not distinguish which subexpression should serve as the root
      // expression. In practice this case should be treated as a bug.
      __Expression(kind: .generic("<expression unavailable>"))
    }
    expression.subexpressions += subexpressions

    return expression
  }

#if !SWT_FIXED_122011759
  /// Storage for any locally-created C strings.
  private var _transformedCStrings = [UnsafeMutablePointer<CChar>]()

  deinit {
    for cString in _transformedCStrings {
      free(cString)
    }
  }
#endif
}

@available(*, unavailable)
extension __ExpectationContext: Sendable {}

// MARK: - Expression capturing

extension __ExpectationContext {
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
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  public mutating func callAsFunction<T>(_ value: T, _ id: __ExpressionID) -> T {
    runtimeValues[id] = { Expression.Value(reflecting: value) }
    return value
  }

#if SWT_SUPPORTS_MOVE_ONLY_EXPRESSION_EXPANSION
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
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @_disfavoredOverload
  public mutating func callAsFunction<T>(_ value: consuming T, _ id: __ExpressionID) -> T where T: ~Copyable {
    // TODO: add support for borrowing non-copyable expressions (need @lifetime)
    return value
  }
#endif

  /// Capture information about a value passed `inout` to a function call after
  /// the function has returned.
  ///
  /// - Parameters:
  ///   - value: The value that was passed `inout` (i.e. with the `&` operator.)
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  public mutating func __inoutAfter<T>(_ value: T, _ id: __ExpressionID) {
    runtimeValues[id] = { Expression.Value(reflecting: value, timing: .after) }
  }
}

// MARK: - Collection comparison and diffing

extension __ExpectationContext {
  /// Convert an instance of `CollectionDifference` to one that is type-erased
  /// over elements of type `Any`.
  ///
  /// - Parameters:
  ///   - difference: The difference to convert.
  ///
  /// - Returns: A type-erased copy of `difference`.
  private static func _typeEraseCollectionDifference(_ difference: CollectionDifference<some Any>) -> CollectionDifference<Any> {
    CollectionDifference<Any>(
      difference.lazy.map { change in
        switch change {
        case let .insert(offset, element, associatedWith):
          return .insert(offset: offset, element: element as Any, associatedWith: associatedWith)
        case let .remove(offset, element, associatedWith):
          return .remove(offset: offset, element: element as Any, associatedWith: associatedWith)
        }
      }
    )!
  }

  /// Generate a description of a previously-computed collection difference.
  ///
  /// - Parameters:
  ///   - difference: The difference to describe.
  ///
  /// - Returns: A human-readable string describing `difference`.
  private static func _description(of difference: CollectionDifference<some Any>) -> String {
    let insertions: [String] = difference.insertions.lazy
      .map(\.element)
      .map(String.init(describingForTest:))
    let removals: [String] = difference.removals.lazy
      .map(\.element)
      .map(String.init(describingForTest:))

    var resultComponents = [String]()
    if !insertions.isEmpty {
      resultComponents.append("inserted [\(insertions.joined(separator: ", "))]")
    }
    if !removals.isEmpty {
      resultComponents.append("removed [\(removals.joined(separator: ", "))]")
    }

    return resultComponents.joined(separator: ", ")
  }

  /// Compare two values using `==` or `!=`.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand operand.
  ///   - lhsID: A value that uniquely identifies the expression represented by
  ///     `lhs` in the context of the expectation currently being evaluated.
  ///   - rhs: The left-hand operand.
  ///   - rhsID: A value that uniquely identifies the expression represented by
  ///     `rhs` in the context of the expectation currently being evaluated.
  ///   - op: A function that performs an operation on `lhs` and `rhs`.
  ///   - opID: A value that uniquely identifies the expression represented by
  ///     `op` in the context of the expectation currently being evaluated.
  ///
  /// - Returns: The result of calling `op(lhs, rhs)`.
  ///
  /// This overload of `__cmp()` serves as a catch-all for operands that are not
  /// collections or otherwise are not interesting to the testing library.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  public mutating func __cmp<T, U, R>(
    _ op: (T, U) throws -> R,
    _ opID: __ExpressionID,
    _ lhs: T,
    _ lhsID: __ExpressionID,
    _ rhs: U,
    _ rhsID: __ExpressionID
  ) rethrows -> R {
    try self(op(self(lhs, lhsID), self(rhs, rhsID)), opID)
  }

  /// Compare two bidirectional collections using `==` or `!=`.
  ///
  /// This overload of `__cmp()` performs a diffing operation on `lhs` and `rhs`
  /// if the result of `op(lhs, rhs)` is `false`.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  public mutating func __cmp<C>(
    _ op: (C, C) -> Bool,
    _ opID: __ExpressionID,
    _ lhs: C,
    _ lhsID: __ExpressionID,
    _ rhs: C,
    _ rhsID: __ExpressionID
  ) -> Bool where C: BidirectionalCollection, C.Element: Equatable {
    let result = self(op(self(lhs, lhsID), self(rhs, rhsID)), opID)

    if !result {
      differences[opID] = { [lhs, rhs] in
        Self._typeEraseCollectionDifference(lhs.difference(from: rhs))
      }
    }

    return result
  }

  /// Compare two range expressions using `==` or `!=`.
  ///
  /// This overload of `__cmp()` does _not_ perform a diffing operation on `lhs`
  /// and `rhs`. Range expressions are not usefully diffable the way other kinds
  /// of collections are. ([#639](https://github.com/swiftlang/swift-testing/issues/639))
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  public mutating func __cmp<R>(
    _ op: (R, R) -> Bool,
    _ opID: __ExpressionID,
    _ lhs: R,
    _ lhsID: __ExpressionID,
    _ rhs: R,
    _ rhsID: __ExpressionID
  ) -> Bool where R: RangeExpression & BidirectionalCollection, R.Element: Equatable {
    self(op(self(lhs, lhsID), self(rhs, rhsID)), opID)
  }

  /// Compare two strings using `==` or `!=`.
  ///
  /// This overload of `__cmp()` performs a diffing operation on `lhs` and `rhs`
  /// if the result of `op(lhs, rhs)` is `false`, but does so by _line_, not by
  /// _character_.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  public mutating func __cmp<S>(
    _ op: (S, S) -> Bool,
    _ opID: __ExpressionID,
    _ lhs: S,
    _ lhsID: __ExpressionID,
    _ rhs: S,
    _ rhsID: __ExpressionID
  ) -> Bool where S: StringProtocol {
    let result = self(op(self(lhs, lhsID), self(rhs, rhsID)), opID)

    if !result {
      differences[opID] = { [lhs, rhs] in
        // Compare strings by line, not by character.
        let lhsLines = String(lhs).split(whereSeparator: \.isNewline)
        let rhsLines = String(rhs).split(whereSeparator: \.isNewline)

        if lhsLines.count == 1 && rhsLines.count == 1 {
          // There are no newlines in either string, so there's no meaningful
          // per-line difference. Bail.
          return nil
        }

        let diff = lhsLines.difference(from: rhsLines)
        if diff.isEmpty {
          // The strings must have compared on a per-character basis, or this
          // operator doesn't behave the way we expected. Bail.
          return nil
        }

        return Self._typeEraseCollectionDifference(diff)
      }
    }

    return result
  }
}

// MARK: - Casting

extension __ExpectationContext {
  /// Perform a conditional cast (`as?`) on a value.
  ///
  /// - Parameters:
  ///   - value: The value to cast.
  ///   - valueID: A value that uniquely identifies the expression represented
  ///     by `value` in the context of the expectation being evaluated.
  ///   - type: The type to cast `value` to.
  ///   - valueID: A value that uniquely identifies the expression represented
  ///     by `type` in the context of the expectation being evaluated.
  ///
  /// - Returns: The result of the expression `value as? type`.
  ///
  /// If `value` cannot be cast to `type`, the previously-recorded context for
  /// the expression `type` is assigned the runtime value `type(of: value)` so
  /// that the _actual_ type of `value` is recorded in any resulting issue.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  public mutating func __as<T, U>(_ value: T, _ valueID: __ExpressionID, _ type: U.Type, _ typeID: __ExpressionID) -> U? {
    let result = self(value, valueID) as? U

    if result == nil {
      let correctType = Swift.type(of: value as Any)
      _ = self(correctType, typeID)
    }

    return result
  }

  /// Check the type of a value using the `is` operator.
  ///
  /// - Parameters:
  ///   - value: The value to cast.
  ///   - valueID: A value that uniquely identifies the expression represented
  ///     by `value` in the context of the expectation being evaluated.
  ///   - type: The type `value` is expected to be.
  ///   - valueID: A value that uniquely identifies the expression represented
  ///     by `type` in the context of the expectation being evaluated.
  ///
  /// - Returns: The result of the expression `value as? type`.
  ///
  /// If `value` is not an instance of `type`, the previously-recorded context
  /// for the expression `type` is assigned the runtime value `type(of: value)`
  /// so that the _actual_ type of `value` is recorded in any resulting issue.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  public mutating func __is<T, U>(_ value: T, _ valueID: __ExpressionID, _ type: U.Type, _ typeID: __ExpressionID) -> Bool {
    let result = self(value, valueID) is U

    if !result {
      let correctType = Swift.type(of: value as Any)
      _ = self(correctType, typeID)
    }

    return result
  }
}

// MARK: - Implicit pointer conversion

extension __ExpectationContext {
  /// Convert some pointer to an immutable one and capture information about it
  /// for use if the expectation currently being evaluated fails.
  ///
  /// - Parameters:
  ///   - value: The pointer to make immutable.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///
  /// - Returns: `value`, cast to an immutable pointer.
  ///
  /// This overload of `callAsFunction(_:_:)` handles the implicit conversions
  /// between various pointer types that are normally provided by the compiler.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @_disfavoredOverload
  public mutating func callAsFunction<P, T>(_ value: P, _ id: __ExpressionID) -> UnsafePointer<T> where P: _Pointer, P.Pointee == T {
    self(value as P?, id)!
  }

  /// Convert some pointer to an immutable one and capture information about it
  /// for use if the expectation currently being evaluated fails.
  ///
  /// - Parameters:
  ///   - value: The pointer to make immutable.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///
  /// - Returns: `value`, cast to an immutable pointer.
  ///
  /// This overload of `callAsFunction(_:_:)` handles the implicit conversions
  /// between various pointer types that are normally provided by the compiler.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @_disfavoredOverload
  public mutating func callAsFunction<P, T>(_ value: P?, _ id: __ExpressionID) -> UnsafePointer<T>? where P: _Pointer, P.Pointee == T {
    value.flatMap { value in
      UnsafePointer<T>(bitPattern: Int(bitPattern: self(value, id) as P))
    }
  }

  /// Convert some pointer to an immutable one and capture information about it
  /// for use if the expectation currently being evaluated fails.
  ///
  /// - Parameters:
  ///   - value: The pointer to make immutable.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///
  /// - Returns: `value`, cast to an immutable pointer.
  ///
  /// This overload of `callAsFunction(_:_:)` handles the implicit conversions
  /// between various pointer types that are normally provided by the compiler.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @_disfavoredOverload
  public mutating func callAsFunction<P>(_ value: P, _ id: __ExpressionID) -> UnsafeRawPointer where P: _Pointer {
    self(value as P?, id)!
  }

  /// Convert some pointer to an immutable one and capture information about it
  /// for use if the expectation currently being evaluated fails.
  ///
  /// - Parameters:
  ///   - value: The pointer to make immutable.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///
  /// - Returns: `value`, cast to an immutable pointer.
  ///
  /// This overload of `callAsFunction(_:_:)` handles the implicit conversions
  /// between various pointer types that are normally provided by the compiler.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @_disfavoredOverload
  public mutating func callAsFunction<P>(_ value: P?, _ id: __ExpressionID) -> UnsafeRawPointer? where P: _Pointer {
    value.flatMap { value in
      UnsafeRawPointer(bitPattern: Int(bitPattern: self(value, id) as P))
    }
  }
}

#if !SWT_FIXED_122011759
// MARK: - String-to-C-string handling

extension __ExpectationContext {
  /// Convert a string to a C string and capture information about it for use if
  /// the expectation currently being evaluated fails.
  ///
  /// - Parameters:
  ///   - value: The string value that should be transformed into a C string.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///
  /// - Returns: `value`, transformed into a pointer to a C string. The caller
  ///   should _not_ free this string; it will be freed when the expectation
  ///   context is destroyed.
  ///
  /// This overload of `callAsFunction(_:_:)` is necessary because Swift allows
  /// passing string literals directly to functions that take C strings. At
  /// compile time, the compiler generates code that makes a temporary UTF-8
  /// copy of the string, then frees that copy on return. That logic does not
  /// work correctly when strings are passed to intermediate functions such as
  /// this one, and the compiler will fail to extend the lifetime of the C
  /// strings to the appropriate point. ([122011759](rdar://122011759))
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  public mutating func callAsFunction<P>(_ value: String, _ id: __ExpressionID) -> P where P: _Pointer, P.Pointee == CChar {
    // Perform the normal value capture.
    let result = self(value, id) as String

    // Create a C string copy of `value`.
#if os(Windows)
    let resultCString = _strdup(result)!
#else
    let resultCString = strdup(result)!
#endif

    // Store the C string pointer so we can free it later when this context is
    // torn down.
    if _transformedCStrings.capacity == 0 {
      _transformedCStrings.reserveCapacity(2)
    }
    _transformedCStrings.append(resultCString)

    // Return the C string as whatever pointer type the caller wants.
    return P(bitPattern: Int(bitPattern: resultCString)).unsafelyUnwrapped
  }
}
#endif

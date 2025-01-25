//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

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
public final class __ExpectationContext {
  /// The source code representations of any captured expressions.
  ///
  /// Unlike the rest of the state in this type, the source code dictionary is
  /// entirely available at compile time and only needs to actually be realized
  /// if an issue is recorded (or more rarely if passing expectations are
  /// reported to the current event handler.) So we can store the dictionary as
  /// a closure instead of always paying the cost to allocate and initialize it.
  private var _sourceCode: @Sendable () -> [__ExpressionID: String]

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
    sourceCode: @escaping @autoclosure @Sendable () -> [__ExpressionID: String] = [:],
    runtimeValues: [__ExpressionID: () -> Expression.Value?] = [:],
    differences: [__ExpressionID: () -> CollectionDifference<Any>?] = [:]
  ) {
    _sourceCode = sourceCode
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
    for (id, sourceCode) in _sourceCode() {
      let keyPath = id.keyPathRepresentation
      expressionGraph.insertValue(__Expression(sourceCode), at: keyPath)
    }

    // If the expectation failed, insert any captured runtime values into the
    // graph alongside the source code.
    if !successfully {
      for (id, runtimeValue) in runtimeValues {
        let keyPath = id.keyPathRepresentation
        if var expression = expressionGraph[keyPath], let runtimeValue = runtimeValue() {
          expression.runtimeValue = runtimeValue
          expressionGraph[keyPath] = expression
        }
      }

      for (id, difference) in differences {
        let keyPath = id.keyPathRepresentation
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
  /// This function helps overloads of `callAsFunction(_:_:)` disambiguate
  /// themselves and avoid accidental recursion.
  @usableFromInline func captureValue<T>(_ value: T, _ id: __ExpressionID) -> T {
    runtimeValues[id] = { Expression.Value(reflecting: value) }
    return value
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
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @_disfavoredOverload
  @inlinable public func callAsFunction<T>(_ value: T, _ id: __ExpressionID) -> T {
    captureValue(value, id)
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
  public func callAsFunction<T>(_ value: consuming T, _ id: __ExpressionID) -> T where T: ~Copyable {
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
  public func __inoutAfter<T>(_ value: T, _ id: __ExpressionID) {
    runtimeValues[id] = { Expression.Value(reflecting: value, timing: .after) }
  }
}

// MARK: - Collection comparison and diffing

extension __ExpectationContext {
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
  @inlinable public func __cmp<T, U>(
    _ op: (T, U) throws -> Bool,
    _ opID: __ExpressionID,
    _ lhs: T,
    _ lhsID: __ExpressionID,
    _ rhs: U,
    _ rhsID: __ExpressionID
  ) rethrows -> Bool {
    try captureValue(op(captureValue(lhs, lhsID), captureValue(rhs, rhsID)), opID)
  }

  /// Compare two bidirectional collections using `==` or `!=`.
  ///
  /// This overload of `__cmp()` performs a diffing operation on `lhs` and `rhs`
  /// if the result of `op(lhs, rhs)` is `false`.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  public func __cmp<C>(
    _ op: (C, C) -> Bool,
    _ opID: __ExpressionID,
    _ lhs: C,
    _ lhsID: __ExpressionID,
    _ rhs: C,
    _ rhsID: __ExpressionID
  ) -> Bool where C: BidirectionalCollection, C.Element: Equatable {
    let result = captureValue(op(captureValue(lhs, lhsID), captureValue(rhs, rhsID)), opID)

    if !result {
      differences[opID] = { CollectionDifference<Any>(lhs.difference(from: rhs)) }
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
  @inlinable public func __cmp<R>(
    _ op: (R, R) -> Bool,
    _ opID: __ExpressionID,
    _ lhs: R,
    _ lhsID: __ExpressionID,
    _ rhs: R,
    _ rhsID: __ExpressionID
  ) -> Bool where R: RangeExpression & BidirectionalCollection, R.Element: Equatable {
    captureValue(op(captureValue(lhs, lhsID), captureValue(rhs, rhsID)), opID)
  }

  /// Compare two strings using `==` or `!=`.
  ///
  /// This overload of `__cmp()` performs a diffing operation on `lhs` and `rhs`
  /// if the result of `op(lhs, rhs)` is `false`, but does so by _line_, not by
  /// _character_.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  public func __cmp<S>(
    _ op: (S, S) -> Bool,
    _ opID: __ExpressionID,
    _ lhs: S,
    _ lhsID: __ExpressionID,
    _ rhs: S,
    _ rhsID: __ExpressionID
  ) -> Bool where S: StringProtocol {
    let result = captureValue(op(captureValue(lhs, lhsID), captureValue(rhs, rhsID)), opID)

    if !result {
      differences[opID] = {
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

        return CollectionDifference<Any>(diff)
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
  @inlinable public func __as<T, U>(_ value: T, _ valueID: __ExpressionID, _ type: U.Type, _ typeID: __ExpressionID) -> U? {
    let result = captureValue(value, valueID) as? U

    if result == nil {
      let correctType = Swift.type(of: value as Any)
      _ = captureValue(correctType, typeID)
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
  @inlinable public func __is<T, U>(_ value: T, _ valueID: __ExpressionID, _ type: U.Type, _ typeID: __ExpressionID) -> Bool {
    let result = captureValue(value, valueID) is U

    if !result {
      let correctType = Swift.type(of: value as Any)
      _ = captureValue(correctType, typeID)
    }

    return result
  }
}

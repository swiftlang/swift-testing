//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
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
/// Instances of this type do _not_ conform to [`Sendable`](https://developer.apple.com/documentation/swift/sendable)
/// because they may capture non-sendable state generated during the evaluation
/// of an expression.
///
/// - Warning: This type is used to implement the `#expect()` and `#require()`
///   macros. Do not use it directly.
public final class __ExpectationContext<Output> where Output: ~Copyable {
  /// The source code representations of any captured expressions.
  ///
  /// Unlike the rest of the state in this type, the source code dictionary is
  /// entirely available at compile time and only needs to actually be realized
  /// if an issue is recorded (or more rarely if passing expectations are
  /// reported to the current event handler.) So we can store the dictionary as
  /// a closure instead of always paying the cost to allocate and initialize it.
  @exclusivity(unchecked)
  private var _sourceCode: @Sendable () -> KeyValuePairs<__ExpressionID, String>

  /// The runtime values of any captured expressions.
  ///
  /// The values in this dictionary are generally gathered at runtime as
  /// subexpressions are evaluated. Not all expressions captured at compile time
  /// will have runtime values: notably, if an operand to a short-circuiting
  /// binary operator like `&&` is not evaluated, the corresponding expression
  /// will not be assigned a runtime value.
  ///
  /// This property is non-optional because the evaluation of an expectation
  /// always produces at least one element.
  @exclusivity(unchecked)
  var runtimeValues: [(__ExpressionID, () -> Expression.Value?)]

  init(
    expressionCapacity: Int? = nil,
    sourceCode: @escaping @autoclosure @Sendable () -> KeyValuePairs<__ExpressionID, String>,
    runtimeValues: KeyValuePairs<__ExpressionID, () -> Expression.Value?>? = nil
  ) {
    _sourceCode = sourceCode
    if let runtimeValues {
      self.runtimeValues = Array(runtimeValues)
    } else {
      self.runtimeValues = Array()
      self.runtimeValues.reserveCapacity(expressionCapacity ?? defaultExpectationContextExpressionCapacity)
    }
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
      __Expression("<expression unavailable>")
    }
    expression.subexpressions += subexpressions

    return expression
  }
}

@available(*, unavailable)
extension __ExpectationContext: Sendable where Output: ~Copyable {}

// MARK: - Expression capturing

extension __ExpectationContext where Output: ~Copyable {
  /// Capture information about a value, encapsulated in an instance of
  /// ``Expression/Value``, for use if the expectation currently being evaluated
  /// fails.
  ///
  /// - Parameters:
  ///   - runtimeValue: The value to pass through. This value is lazily
  ///     evaluated on expectation failure only.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  func captureValue(_ runtimeValue: @escaping @autoclosure () -> Expression.Value?, identifiedBy id: __ExpressionID) {
    runtimeValues.append((id, runtimeValue))
  }

  /// Capture information about a value for use if the expectation currently
  /// being evaluated fails.
  ///
  /// - Parameters:
  ///   - value: The value to pass through.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///
  /// This function helps subscript overloads disambiguate themselves and avoid
  /// accidental recursion.
  func captureValue<T>(_ value: T, identifiedBy id: __ExpressionID) where T: Copyable & Escapable {
    captureValue(Expression.Value(reflecting: value), identifiedBy: id)
  }

  /// Capture information about a value for use if the expectation currently
  /// being evaluated fails.
  ///
  /// - Parameters:
  ///   - value: The value to pass through.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///
  /// This function helps subscript overloads disambiguate themselves and avoid
  /// accidental recursion.
  func captureValue<T>(_ value: borrowing T, identifiedBy id: __ExpressionID) where T: ~Copyable & ~Escapable {
    if #available(_castingWithNonCopyableGenerics, *), let value = makeExistential(value) {
      captureValue(Expression.Value(reflecting: value), identifiedBy: id)
    } else {
      captureValue(Expression.Value(failingToReflectInstanceOf: T.self), identifiedBy: id)
    }
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
  public func callAsFunction<T>(_ value: borrowing T, _ id: __ExpressionID) -> T where T: Copyable & Escapable {
    captureValue(value, identifiedBy: id)
    return copy value
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
  @_lifetime(borrow value)
  public func callAsFunction<T>(_ value: borrowing T, _ id: __ExpressionID) -> T where T: Copyable & ~Escapable {
    captureValue(value, identifiedBy: id)
    return copy value
  }

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
  public func __inoutAfter<T>(_ value: inout T, _ id: __ExpressionID) where T: Copyable & Escapable {
    captureValue(value, identifiedBy: id)
  }

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
  public func __inoutAfter<T>(_ value: inout T, _ id: __ExpressionID) where T: ~Copyable & ~Escapable {
    captureValue(value, identifiedBy: id)
  }
}

// MARK: - Casting

extension __ExpectationContext where Output: ~Copyable {
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
  public func __as<T, U>(_ value: borrowing T, _ valueID: __ExpressionID, _ type: U.Type, _ typeID: __ExpressionID) -> U? {
    let value = copy value

    captureValue(value, identifiedBy: valueID)
    let result = value as? U

    if result == nil {
      let correctType = Swift.type(of: value as Any)
      captureValue(correctType, identifiedBy: typeID)
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
  public func __is<T, U>(_ value: borrowing T, _ valueID: __ExpressionID, _ type: U.Type, _ typeID: __ExpressionID) -> Bool {
    __as(value, valueID, type, typeID) != nil
  }
}

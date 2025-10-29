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
extension __ExpectationContext: Sendable where Output: ~Copyable {}

// MARK: - Expression capturing

extension __ExpectationContext where Output: ~Copyable {
  /// Capture information about a value for use if the expectation currently
  /// being evaluated fails.
  ///
  /// - Parameters:
  ///   - value: The value to pass through.
  ///   - id: A value that uniquely identifies the represented expression in the
  ///     context of the expectation currently being evaluated.
  ///   - timing: When the value represented by this instance was captured.
  ///
  /// - Returns: `value`, verbatim.
  ///
  /// This function helps overloads of `callAsFunction(_:_:)` disambiguate
  /// themselves and avoid accidental recursion.
  func captureValue<T>(_ value: borrowing T, _ id: __ExpressionID, timing: Expression.Value.Timing?) -> T {
    let value = copy value
    runtimeValues[id] = { Expression.Value(reflecting: value, timing: timing) }
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
  /// This function helps overloads of `callAsFunction(_:_:)` disambiguate
  /// themselves and avoid accidental recursion.
  @usableFromInline func captureValue<T>(_ value: borrowing T, _ id: __ExpressionID) -> T {
    captureValue(value, id, timing: nil)
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
  @inlinable public func callAsFunction<T>(_ value: borrowing T, _ id: __ExpressionID) -> T {
    captureValue(value, id)
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
  public func __inoutAfter<T>(_ value: borrowing T, _ id: __ExpressionID) {
    _ = captureValue(value, id, timing: .after)
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
    if #available(_castingWithNonCopyableGenerics, *), let value = boxCopyableValue(value) {
      _ = captureValue(value, id)
    }
    return value
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
  @_disfavoredOverload
  public func __inoutAfter<T>(_ value: borrowing T, _ id: __ExpressionID) where T: ~Copyable {
    if #available(_castingWithNonCopyableGenerics, *), let value = boxCopyableValue(value) {
      __inoutAfter(value, id)
    }
  }
#endif
}

// MARK: - Collection comparison and diffing

extension __ExpectationContext where Output: ~Copyable {
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

  /// Capture the difference between `lhs` and `rhs` at runtime.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand operand.
  ///   - rhs: The right-hand operand.
  ///   - opID: A value that uniquely identifies the binary operation expression
  ///     of which `lhs` and `rhs` are operands.
  ///
  /// This function performs additional type checking of `lhs` and `rhs` at
  /// runtime. If we instead overload the caller (`__cmp()`) it puts extra
  /// compile-time pressure on the type checker that we don't want.
  @usableFromInline func captureDifferences<T, U>(_ lhs: T, _ rhs: U, _ opID: __ExpressionID) {
#if !hasFeature(Embedded) // no existentials
    if let lhs = lhs as? any StringProtocol {
      func open<V>(_ lhs: V, _ rhs: U) where V: StringProtocol {
        guard let rhs = rhs as? V else {
          return
        }
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
      open(lhs, rhs)
    } else if lhs is any RangeExpression {
      // Do _not_ perform a diffing operation on `lhs` and `rhs`. Range
      // expressions are not usefully diffable the way other kinds of
      // collections are. SEE: https://github.com/swiftlang/swift-testing/issues/639
    } else if let lhs = lhs as? any BidirectionalCollection {
      func open<V>(_ lhs: V, _ rhs: U) where V: BidirectionalCollection {
        guard let rhs = rhs as? V,
              let elementType = V.Element.self as? any Equatable.Type else {
          return
        }
        differences[opID] = {
          func open<E>(_: E.Type) -> CollectionDifference<Any> where E: Equatable {
            let lhs: some BidirectionalCollection<E> = lhs.lazy.map { $0 as! E }
            let rhs: some BidirectionalCollection<E> = rhs.lazy.map { $0 as! E }
            return CollectionDifference<Any>(lhs.difference(from: rhs))
          }
          return open(elementType)
        }
      }
      open(lhs, rhs)
    }
#endif
  }

  /// Compare two values using `==` or `!=`.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand operand.
  ///   - lhsID: A value that uniquely identifies the expression represented by
  ///     `lhs` in the context of the expectation currently being evaluated.
  ///   - rhs: The right-hand operand.
  ///   - rhsID: A value that uniquely identifies the expression represented by
  ///     `rhs` in the context of the expectation currently being evaluated.
  ///   - op: A function that performs an operation on `lhs` and `rhs`.
  ///   - opID: A value that uniquely identifies the expression represented by
  ///     `op` in the context of the expectation currently being evaluated.
  ///
  /// - Returns: The result of calling `op(lhs, rhs)`.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @inlinable public func __cmp<T, U>(
    _ op: (borrowing T, borrowing U) throws -> Bool,
    _ opID: __ExpressionID,
    _ lhs: borrowing T,
    _ lhsID: __ExpressionID,
    _ rhs: borrowing U,
    _ rhsID: __ExpressionID
  ) rethrows -> Bool {
    let result = try captureValue(op(captureValue(lhs, lhsID), captureValue(rhs, rhsID)), opID)

    if !result {
      captureDifferences(lhs, rhs, opID)
    }

    return result
  }

#if SWT_SUPPORTS_MOVE_ONLY_EXPRESSION_EXPANSION
  /// Compare two values using `==` or `!=`.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand operand.
  ///   - lhsID: A value that uniquely identifies the expression represented by
  ///     `lhs` in the context of the expectation currently being evaluated.
  ///   - rhs: The right-hand operand.
  ///   - rhsID: A value that uniquely identifies the expression represented by
  ///     `rhs` in the context of the expectation currently being evaluated.
  ///   - op: A function that performs an operation on `lhs` and `rhs`.
  ///   - opID: A value that uniquely identifies the expression represented by
  ///     `op` in the context of the expectation currently being evaluated.
  ///
  /// - Returns: The result of calling `op(lhs, rhs)`.
  ///
  /// This overload of `__cmp()` handles move-only values.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  @_disfavoredOverload
  public func __cmp<T, U>(
    _ op: (borrowing T, borrowing U) throws -> Bool,
    _ opID: __ExpressionID,
    _ lhs: borrowing T,
    _ lhsID: __ExpressionID,
    _ rhs: borrowing U,
    _ rhsID: __ExpressionID
  ) rethrows -> Bool where T: ~Copyable, U: ~Copyable {
    let result = try captureValue(op(lhs, rhs), opID)

    if #available(_castingWithNonCopyableGenerics, *) {
      let lhs = boxCopyableValue(lhs)
      if let lhs {
        _ = captureValue(lhs, lhsID)
      }
      let rhs = boxCopyableValue(rhs)
      if let rhs {
        _ = captureValue(rhs, rhsID)
      }
      if !result {
        captureDifferences(lhs, rhs, opID)
      }
    }

    return result
  }
#endif
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
  @inlinable public func __as<T, U>(_ value: borrowing T, _ valueID: __ExpressionID, _ type: U.Type, _ typeID: __ExpressionID) -> U? {
    let result = captureValue(value, valueID) as? U

    if result == nil {
      let correctType = Swift.type(of: (copy value) as Any)
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
  @inlinable public func __is<T, U>(_ value: borrowing T, _ valueID: __ExpressionID, _ type: U.Type, _ typeID: __ExpressionID) -> Bool {
    __as(value, valueID, type, typeID) != nil
  }
}

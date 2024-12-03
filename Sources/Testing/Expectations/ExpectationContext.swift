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

  init(sourceCode: [__ExpressionID: String] = [:], runtimeValues: [__ExpressionID: () -> Expression.Value?] = [:]) {
    self.sourceCode = sourceCode
    self.runtimeValues = runtimeValues
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
  /// This function should ideally be `consuming`, but because it is used in a
  /// `lazy var` declaration, the compiler currently disallows it.
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
  public mutating func callAsFunction<T>(_ value: T, _ id: __ExpressionID) -> T where T: Copyable {
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
  public mutating func callAsFunction<T>(_ value: consuming T, _ id: __ExpressionID) -> T where T: ~Copyable {
    // TODO: add support for borrowing non-copyable expressions (need @lifetime)
    return value
  }

  /// Perform a conditional cast (`as?`) on a value.
  ///
  /// - Parameters:
  ///   - value: The value to cast.
  ///   - type: The type to cast `value` to.
  ///   - typeID: The ID chain of the `type` expression as emitted during
  ///     expansion of the `#expect()` or `#require()` macro.
  ///
  /// - Returns: The result of the expression `value as? type`.
  ///
  /// If `value` cannot be cast to `type`, the previously-recorded context for
  /// the expression `type` is assigned the runtime value `type(of: value)` so
  /// that the _actual_ type of `value` is recorded in any resulting issue.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  public mutating func __as<T, U>(_ value: T, _ type: U.Type, _ typeID: __ExpressionID) -> U? {
    let result = value as? U

    if result == nil {
      let correctType = Swift.type(of: value as Any)
      runtimeValues[typeID] = { Expression.Value(reflecting: correctType) }
    }

    return result
  }

  /// Check the type of a value using the `is` operator.
  ///
  /// - Parameters:
  ///   - value: The value to cast.
  ///   - type: The type `value` is expected to be.
  ///   - typeID: The ID chain of the `type` expression as emitted during
  ///     expansion of the `#expect()` or `#require()` macro.
  ///
  /// - Returns: The result of the expression `value as? type`.
  ///
  /// If `value` is not an instance of `type`, the previously-recorded context
  /// for the expression `type` is assigned the runtime value `type(of: value)`
  /// so that the _actual_ type of `value` is recorded in any resulting issue.
  ///
  /// - Warning: This function is used to implement the `#expect()` and
  ///   `#require()` macros. Do not call it directly.
  public mutating func __is<T, U>(_ value: T, _ type: U.Type, _ typeID: __ExpressionID) -> Bool {
    let result = value is U

    if !result {
      let correctType = Swift.type(of: value as Any)
      runtimeValues[typeID] = { Expression.Value(reflecting: correctType) }
    }

    return result
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
  public mutating func callAsFunction<T, U>(_ value: T, _ id: __ExpressionID) -> U where T: StringProtocol, U: _Pointer {
    // Perform the normal value capture.
    let result = self(value, id)

    // Create a C string copy of `value`.
#if os(Windows)
    let resultCString = _strdup(String(result))!
#else
    let resultCString = strdup(String(result))!
#endif

    // Store the C string pointer so we can free it later when this context is
    // torn down.
    if _transformedCStrings.capacity == 0 {
      _transformedCStrings.reserveCapacity(2)
    }
    _transformedCStrings.append(resultCString)

    // Return the C string as whatever pointer type the caller wants.
    return U(bitPattern: Int(bitPattern: resultCString)).unsafelyUnwrapped
  }
}
#endif

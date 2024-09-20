//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
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
public struct __ExpectationContext {
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
  private func _squashExpressionGraph(_ expressionGraph: Graph<UInt32, __Expression?>, depth: Int) -> [__Expression] {
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
  consuming func finalize(successfully: Bool) -> __Expression {
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
  private var _transformedCStrings: _TransformedCStrings?
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

    return true
  }
}

#if !SWT_FIXED_122011759
// MARK: - String-to-C-string handling

extension __ExpectationContext {
  /// A class that manages the lifetimes of any temporary C strings created in
  /// the context of an expectation.
  private final class _TransformedCStrings {
    var values = [UnsafeMutablePointer<CChar>]()

    deinit {
      for cString in values {
        free(cString)
      }
    }
  }

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
    if _transformedCStrings == nil {
      _transformedCStrings = _TransformedCStrings()
    }
    _transformedCStrings?.values.append(resultCString)

    // Return the C string as whatever pointer type the caller wants.
    return U(bitPattern: Int(bitPattern: resultCString)).unsafelyUnwrapped
  }
}
#endif

// MARK: - Condition checking

/// Check that an expectation has passed after a condition has been evaluated
/// and throw an error if it failed.
///
/// - Parameters:
///   - condition: The condition to be evaluated.
///   - expectationContext: The expectation context, created by the caller, that
///     contains information about `condition` and its subexpressions (if any.)
///   - mismatchedErrorDescription: A description of the thrown error that did
///     not match the expectation, if applicable.
///   - mismatchedExitConditionDescription: A description of the exit condition
///     of the child process that did not match the expectation, if applicable.
///   - comments: An array of comments describing the expectation. This array
///     may be empty.
///   - isRequired: Whether or not the expectation is required. The value of
///     this argument does not affect whether or not an error is thrown on
///     failure.
///   - sourceLocation: The source location of the expectation.
///
/// - Returns: A `Result<Void, any Error>`. If `condition` is `true`, the result
///   is `.success`. If `condition` is `false`, the result is an instance of
///   ``ExpectationFailedError`` describing the failure.
///
/// If the condition evaluates to `false`, an ``Issue`` is recorded for the test
/// that is running in the current task.
///
/// The odd error-handling convention in this function is necessary so that we
/// don't accidentally suppress errors thrown from subexpressions inside the
/// condition. For example, assuming there is a function
/// `func f() throws -> Bool`, the following calls should _not_ throw an
/// instance of ``ExpectationFailedError``, but should also not prevent an error
/// from being thrown by `f()`:
///
/// ```swift
/// try #expect(f))
/// #expect(try f())
/// ```
///
/// And the following call should generate a compile-time error:
///
/// ```swift
/// #expect(f()) // ERROR: Call can throw but is not marked with 'try'
/// ```
///
/// By _returning_ the error this function "throws", we can customize whether or
/// not we throw that error during macro resolution without affecting any errors
/// thrown by the condition expression passed to it.
func check(
  _ condition: Bool,
  expectationContext: consuming __ExpectationContext,
  mismatchedErrorDescription: @autoclosure () -> String?,
  mismatchedExitConditionDescription: @autoclosure () -> String?,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) -> Result<Void, any Error> {
  let expectationContext = consume expectationContext

  // Post an event for the expectation regardless of whether or not it passed.
  // If the current event handler is not configured to handle events of this
  // kind, this event is discarded.
  lazy var expectation = Expectation(
    evaluatedExpression: expectationContext.finalize(successfully: condition),
    isPassing: condition,
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
  if Configuration.deliverExpectationCheckedEvents {
    Event.post(.expectationChecked(expectation))
  }

  // Early exit if the expectation passed.
  if condition {
    return .success(())
  }

  // Since this expectation failed, populate its optional fields which are
  // only evaluated and included lazily upon failure.
  expectation.mismatchedErrorDescription = mismatchedErrorDescription()
  expectation.mismatchedExitConditionDescription = mismatchedExitConditionDescription()

  // Ensure the backtrace is captured here so it has fewer extraneous frames
  // from the testing framework which aren't relevant to the user.
  let backtrace = Backtrace.current()
  let issue = Issue(kind: .expectationFailed(expectation), comments: comments(), sourceContext: .init(backtrace: backtrace, sourceLocation: sourceLocation))
  issue.record()

  return .failure(ExpectationFailedError(expectation: expectation))
}

// MARK: - Expectation checks

/// A function that evaluates some boolean condition value on behalf of
/// `#expect()` or `#require()`.
///
/// - Warning: This function is used to implement the `#expect()` and
///   `#require()` macros. Do not call it directly.
public func __checkCondition(
  _ condition: (inout __ExpectationContext) throws -> Bool,
  sourceCode: [__ExpressionID: String],
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) rethrows -> Result<Void, any Error> {
  var expectationContext = __ExpectationContext(sourceCode: sourceCode)
  let condition = try condition(&expectationContext)

  return check(
    condition,
    expectationContext: expectationContext,
    mismatchedErrorDescription: nil,
    mismatchedExitConditionDescription: nil,
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}

/// A function that evaluates some optional condition value on behalf of
/// `#expect()` or `#require()`.
///
/// - Warning: This function is used to implement the `#expect()` and
///   `#require()` macros. Do not call it directly.
public func __checkCondition<T>(
  _ optionalValue: (inout __ExpectationContext) throws -> T?,
  sourceCode: [__ExpressionID: String],
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) rethrows -> Result<T, any Error> where T: ~Copyable {
  var expectationContext = __ExpectationContext(sourceCode: sourceCode)
  let optionalValue = try optionalValue(&expectationContext)

  let result = check(
    optionalValue != nil,
    expectationContext: expectationContext,
    mismatchedErrorDescription: nil,
    mismatchedExitConditionDescription: nil,
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )

  switch result {
  case .success:
    return .success(optionalValue!)
  case let .failure(error):
    return .failure(error)
  }
}

// MARK: - Asynchronous expectation checks

/// A function that evaluates some asynchronous boolean condition value on
/// behalf of `#expect()` or `#require()`.
///
/// - Warning: This function is used to implement the `#expect()` and
///   `#require()` macros. Do not call it directly.
public func __checkConditionAsync(
  _ condition: (inout __ExpectationContext) async throws -> Bool,
  sourceCode: [__ExpressionID: String],
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  isolation: isolated (any Actor)? = #isolation,
  sourceLocation: SourceLocation
) async rethrows -> Result<Void, any Error> {
  var expectationContext = __ExpectationContext(sourceCode: sourceCode)
  let condition = try await condition(&expectationContext)

  return check(
    condition,
    expectationContext: expectationContext,
    mismatchedErrorDescription: nil,
    mismatchedExitConditionDescription: nil,
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}

/// A function that evaluates some asynchronous optional condition value on
/// behalf of `#expect()` or `#require()`.
///
/// - Warning: This function is used to implement the `#expect()` and
///   `#require()` macros. Do not call it directly.
public func __checkConditionAsync<T>(
  _ optionalValue: (inout __ExpectationContext) async throws -> sending T?,
  sourceCode: [__ExpressionID: String],
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  isolation: isolated (any Actor)? = #isolation,
  sourceLocation: SourceLocation
) async rethrows -> Result<T, any Error> where T: ~Copyable {
  var expectationContext = __ExpectationContext(sourceCode: sourceCode)
  let optionalValue = try await optionalValue(&expectationContext)

  let result = check(
    optionalValue != nil,
    expectationContext: expectationContext,
    mismatchedErrorDescription: nil,
    mismatchedExitConditionDescription: nil,
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )

  switch result {
  case .success:
    return .success(optionalValue!)
  case let .failure(error):
    return .failure(error)
  }
}

// MARK: - "Escape hatch" expectation checks

/// The "escape hatch" overload of `__check()` that is used when a developer has
/// opted out of most of the magic of macro expansion (presumably due to a
/// miscompile.)
///
/// - Warning: This function is used to implement the `#expect()` and
///   `#require()` macros. Do not call it directly.
public func __checkEscapedCondition(
  _ condition: Bool,
  sourceCode: String,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) -> Result<Void, any Error> {
  var expectationContext = __ExpectationContext()
  expectationContext.sourceCode[""] = sourceCode

  return check(
    condition,
    expectationContext: expectationContext,
    mismatchedErrorDescription: nil,
    mismatchedExitConditionDescription: nil,
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}

/// The "escape hatch" overload of `__check()` that is used when a developer has
/// opted out of most of the magic of macro expansion (presumably due to a
/// miscompile.)
///
/// This overload is used when the expectation is unwrapping an optional value.
///
/// - Warning: This function is used to implement the `#expect()` and
///   `#require()` macros. Do not call it directly.
public func __checkEscapedCondition<T>(
  _ optionalValue: consuming T?,
  sourceCode: String,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) -> Result<T, any Error> where T: ~Copyable {
  var expectationContext = __ExpectationContext()
  expectationContext.sourceCode[""] = sourceCode

  let result = check(
    optionalValue != nil,
    expectationContext: expectationContext,
    mismatchedErrorDescription: nil,
    mismatchedExitConditionDescription: nil,
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )

  switch result {
  case .success:
    return .success(optionalValue!)
  case let .failure(error):
    return .failure(error)
  }
}

// MARK: - Matching errors by type

/// Check that an expression always throws an error.
///
/// This overload is used for `#expect(throws:) { }` invocations that take error
/// types.
///
/// - Warning: This function is used to implement the `#expect()` and
///   `#require()` macros. Do not call it directly.
public func __checkClosureCall<E>(
  throws errorType: E.Type,
  performing body: () throws -> some Any,
  sourceCode: String,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) -> Result<Void, any Error> where E: Error {
  if errorType == Never.self {
    __checkClosureCall(
      throws: Never.self,
      performing: body,
      sourceCode: sourceCode,
      comments: comments(),
      isRequired: isRequired,
      sourceLocation: sourceLocation
    )
  } else {
    __checkClosureCall(
      performing: body,
      throws: { $0 is E },
      mismatchExplanation: { "expected error of type \(errorType), but \(_description(of: $0)) was thrown instead" },
      sourceCode: sourceCode,
      comments: comments(),
      isRequired: isRequired,
      sourceLocation: sourceLocation
    )
  }
}

/// Check that an expression always throws an error.
///
/// This overload is used for `await #expect(throws:) { }` invocations that take
/// error types.
///
/// - Warning: This function is used to implement the `#expect()` and
///   `#require()` macros. Do not call it directly.
public func __checkClosureCall<E>(
  throws errorType: E.Type,
  performing body: () async throws -> sending some Any,
  sourceCode: String,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  isolation: isolated (any Actor)? = #isolation,
  sourceLocation: SourceLocation
) async -> Result<Void, any Error> where E: Error {
  if errorType == Never.self {
    await __checkClosureCall(
      throws: Never.self,
      performing: body,
      sourceCode: sourceCode,
      comments: comments(),
      isRequired: isRequired,
      isolation: isolation,
      sourceLocation: sourceLocation
    )
  } else {
    await __checkClosureCall(
      performing: body,
      throws: { $0 is E },
      mismatchExplanation: { "expected error of type \(errorType), but \(_description(of: $0)) was thrown instead" },
      sourceCode: sourceCode,
      comments: comments(),
      isRequired: isRequired,
      isolation: isolation,
      sourceLocation: sourceLocation
    )
  }
}

// MARK: - Matching Never.self

/// Check that an expression never throws an error.
///
/// This overload is used for `#expect(throws: Never.self) { }`. It cannot be
/// implemented directly in terms of the other overloads because it checks for
/// the _absence_ of an error rather than an error that matches some predicate.
///
/// - Warning: This function is used to implement the `#expect()` and
///   `#require()` macros. Do not call it directly.
public func __checkClosureCall(
  throws _: Never.Type,
  performing body: () throws -> some Any,
  sourceCode: String,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) -> Result<Void, any Error> {
  var success = true
  var mismatchExplanationValue: String? = nil
  do {
    _ = try body()
  } catch {
    success = false
    mismatchExplanationValue = "an error was thrown when none was expected: \(_description(of: error))"
  }

  var expectationContext = __ExpectationContext()
  expectationContext.sourceCode[""] = sourceCode
  return check(
    success,
    expectationContext: expectationContext,
    mismatchedErrorDescription: mismatchExplanationValue,
    mismatchedExitConditionDescription: nil,
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}

/// Check that an expression never throws an error.
///
/// This overload is used for `await #expect(throws: Never.self) { }`. It cannot
/// be implemented directly in terms of the other overloads because it checks
/// for the _absence_ of an error rather than an error that matches some
/// predicate.
///
/// - Warning: This function is used to implement the `#expect()` and
///   `#require()` macros. Do not call it directly.
public func __checkClosureCall(
  throws _: Never.Type,
  performing body: () async throws -> sending some Any,
  sourceCode: String,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  isolation: isolated (any Actor)? = #isolation,
  sourceLocation: SourceLocation
) async -> Result<Void, any Error> {
  var success = true
  var mismatchExplanationValue: String? = nil
  do {
    _ = try await body()
  } catch {
    success = false
    mismatchExplanationValue = "an error was thrown when none was expected: \(_description(of: error))"
  }

  var expectationContext = __ExpectationContext()
  expectationContext.sourceCode[""] = sourceCode
  return check(
    success,
    expectationContext: expectationContext,
    mismatchedErrorDescription: mismatchExplanationValue,
    mismatchedExitConditionDescription: nil,
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}

// MARK: - Matching instances of equatable errors

/// Check that an expression always throws an error.
///
/// This overload is used for `#expect(throws:) { }` invocations that take error
/// instances.
///
/// - Warning: This function is used to implement the `#expect()` and
///   `#require()` macros. Do not call it directly.
public func __checkClosureCall<E>(
  throws error: E,
  performing body: () throws -> some Any,
  sourceCode: String,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) -> Result<Void, any Error> where E: Error & Equatable {
  __checkClosureCall(
    performing: body,
    throws: { true == (($0 as? E) == error) },
    mismatchExplanation: { "expected error \(_description(of: error)), but \(_description(of: $0)) was thrown instead" },
    sourceCode: sourceCode,
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}

/// Check that an expression always throws an error.
///
/// This overload is used for `await #expect(throws:) { }` invocations that take
/// error instances.
///
/// - Warning: This function is used to implement the `#expect()` and
///   `#require()` macros. Do not call it directly.
public func __checkClosureCall<E>(
  throws error: E,
  performing body: () async throws -> sending some Any,
  sourceCode: String,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  isolation: isolated (any Actor)? = #isolation,
  sourceLocation: SourceLocation
) async -> Result<Void, any Error> where E: Error & Equatable {
  await __checkClosureCall(
    performing: body,
    throws: { true == (($0 as? E) == error) },
    mismatchExplanation: { "expected error \(_description(of: error)), but \(_description(of: $0)) was thrown instead" },
    sourceCode: sourceCode,
    comments: comments(),
    isRequired: isRequired,
    isolation: isolation,
    sourceLocation: sourceLocation
  )
}

// MARK: - Arbitrary error matching

/// Check that an expression always throws an error.
///
/// This overload is used for `#expect { } throws: { }` invocations.
///
/// - Warning: This function is used to implement the `#expect()` and
///   `#require()` macros. Do not call it directly.
public func __checkClosureCall<R>(
  performing body: () throws -> R,
  throws errorMatcher: (any Error) throws -> Bool,
  mismatchExplanation: ((any Error) -> String)? = nil,
  sourceCode: String,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) -> Result<Void, any Error> {
  var expectationContext = __ExpectationContext()
  expectationContext.sourceCode[""] = sourceCode

  var errorMatches = false
  var mismatchExplanationValue: String? = nil
  do {
    let result = try body()

    var explanation = "an error was expected but none was thrown"
    if R.self != Void.self {
      explanation += " and \"\(result)\" was returned"
    }
    mismatchExplanationValue = explanation
  } catch {
    expectationContext.runtimeValues[""] = { Expression.Value(reflecting: error) }
    let secondError = Issue.withErrorRecording(at: sourceLocation) {
      errorMatches = try errorMatcher(error)
    }
    if let secondError {
      mismatchExplanationValue = "a second error \(_description(of: secondError)) was thrown when checking error \(_description(of: error))"
    } else if !errorMatches {
      mismatchExplanationValue = mismatchExplanation?(error) ?? "unexpected error \(_description(of: error)) was thrown"
    }
  }

  return check(
    errorMatches,
    expectationContext: expectationContext,
    mismatchedErrorDescription: mismatchExplanationValue,
    mismatchedExitConditionDescription: nil,
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}

/// Check that an expression always throws an error.
///
/// This overload is used for `await #expect { } throws: { }` invocations.
///
/// - Warning: This function is used to implement the `#expect()` and
///   `#require()` macros. Do not call it directly.
public func __checkClosureCall<R>(
  performing body: () async throws -> sending R,
  throws errorMatcher: (any Error) async throws -> Bool,
  mismatchExplanation: ((any Error) -> String)? = nil,
  sourceCode: String,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  isolation: isolated (any Actor)? = #isolation,
  sourceLocation: SourceLocation
) async -> Result<Void, any Error> {
  var expectationContext = __ExpectationContext()
  expectationContext.sourceCode[""] = sourceCode

  var errorMatches = false
  var mismatchExplanationValue: String? = nil
  do {
    let result = try await body()

    var explanation = "an error was expected but none was thrown"
    if R.self != Void.self {
      explanation += " and \"\(result)\" was returned"
    }
    mismatchExplanationValue = explanation
  } catch {
    expectationContext.runtimeValues[""] = { Expression.Value(reflecting: error) }
    let secondError = await Issue.withErrorRecording(at: sourceLocation) {
      errorMatches = try await errorMatcher(error)
    }
    if let secondError {
      mismatchExplanationValue = "a second error \(_description(of: secondError)) was thrown when checking error \(_description(of: error))"
    } else if !errorMatches {
      mismatchExplanationValue = mismatchExplanation?(error) ?? "unexpected error \(_description(of: error)) was thrown"
    }
  }

  return check(
    errorMatches,
    expectationContext: expectationContext,
    mismatchedErrorDescription: mismatchExplanationValue,
    mismatchedExitConditionDescription: nil,
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}

// MARK: - Exit tests

#if !SWT_NO_EXIT_TESTS
/// Check that an expression always exits (terminates the current process) with
/// a given status.
///
/// This overload is used for `await #expect(exitsWith:) { }` invocations. Note
/// that the `body` argument is thin here because it cannot meaningfully capture
/// state from the enclosing context.
///
/// - Warning: This function is used to implement the `#expect()` and
///   `#require()` macros. Do not call it directly.
@_spi(Experimental)
public func __checkClosureCall(
  exitsWith expectedExitCondition: ExitCondition,
  observing observedValues: [any PartialKeyPath<ExitTestArtifacts> & Sendable],
  performing body: @convention(thin) () -> Void,
  sourceCode: String,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  isolation: isolated (any Actor)? = #isolation,
  sourceLocation: SourceLocation
) async -> Result<ExitTestArtifacts?, any Error> {
  await callExitTest(
    exitsWith: expectedExitCondition,
    observing: observedValues,
    sourceCode: sourceCode,
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}
#endif

// MARK: -

/// Generate a description of an error that includes its type name if not
/// already present.
///
/// - Parameters:
///   - error: The error to describe.
///
/// - Returns: A string equivalent to `String(describing: error)` with
///   information about its type added if not already present.
private func _description(of error: some Error) -> String {
  let errorDescription = "\"\(error)\""
  let errorType = type(of: error as Any)
  if #available(_regexAPI, *) {
    if errorDescription.contains(String(describing: errorType)) {
      return errorDescription
    }
  }
  return "\(errorDescription) of type \(errorType)"
}

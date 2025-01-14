//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type that defines a condition which must be satisfied for a test to be
/// enabled.
///
/// To add this trait to a test, use one of the following functions:
///
/// - ``Trait/enabled(if:_:sourceLocation:)``
/// - ``Trait/enabled(_:sourceLocation:_:)``
/// - ``Trait/disabled(_:sourceLocation:)``
/// - ``Trait/disabled(if:_:sourceLocation:)``
/// - ``Trait/disabled(_:sourceLocation:_:)``
public struct ConditionTrait: TestTrait, SuiteTrait {
  /// The result of evaluating the condition.
  public typealias Evaluation = (Bool, comment: Comment?)
  
  /// An enumeration describing the kinds of conditions that can be represented
  /// by an instance of this type.
  enum Kind: Sendable {
    /// The trait is conditional on the result of calling a function.
    ///
    /// - Parameters:
    ///   - body: The function to call. The result of this function determines
    ///     if the condition is satisfied or not. If this function returns
    ///     `false` and a comment is also returned, it is used in place of the
    ///     value of the associated trait's ``ConditionTrait/comment`` property.
    ///     If this function returns `true`, the returned comment is ignored.
    case conditional(_ body: @Sendable () async throws -> Evaluation)

    /// Create an instance of this type associated with a trait that is
    /// conditional on the result of calling a function.
    ///
    /// - Parameters:
    ///   - body: The function to call. The result of this function determines
    ///     whether or not the condition was met.
    ///
    /// - Returns: An instance of this type.
    static func conditional(_ body: @escaping @Sendable () async throws -> Bool) -> Self {
      conditional { () -> Evaluation in
        return (try await body(), nil)
      }
    }

    /// The trait is unconditional and always has the same result.
    ///
    /// - Parameters:
    ///   - value: Whether or not the condition was met.
    case unconditional(_ value: Bool)
  }

  /// The kind of condition represented by this instance.
  var kind: Kind

  /// Whether or not this trait has a condition that is evaluated at runtime.
  ///
  /// If this trait was created using a function such as
  /// ``disabled(_:sourceLocation:)`` that unconditionally enables or disables a
  /// test, the value of this property is `true`.
  ///
  /// If this trait was created using a function such as
  /// ``enabled(if:_:sourceLocation:)`` that is evaluated at runtime, the value
  /// of this property is `false`.
  @_spi(ForToolsIntegrationOnly)
  public var isConstant: Bool {
    switch kind {
    case .conditional:
      return false
    case .unconditional:
      return true
    }
  }

  public var comments: [Comment]

  /// The source location where this trait was specified.
  public var sourceLocation: SourceLocation
  
  /// Returns the result of evaluating the condition.
  @_spi(Experimental)
  public func evaluate() async throws -> Evaluation {
    switch kind {
    case let .conditional(condition):
      try await condition()
    case let .unconditional(unconditionalValue):
      (unconditionalValue, nil)
    }
  }

  public func prepare(for test: Test) async throws {
    let (isEnabled, commentOverride) = try await evaluate()

    if !isEnabled {
      // We don't need to consider including a backtrace here because it will
      // primarily contain frames in the testing library, not user code. If an
      // error was thrown by a condition evaluated above, the caller _should_
      // attempt to get the backtrace of the caught error when creating an issue
      // for it, however.
      let sourceContext = SourceContext(backtrace: nil, sourceLocation: sourceLocation)
      throw SkipInfo(comment: commentOverride ?? comments.first, sourceContext: sourceContext)
    }
  }

  public var isRecursive: Bool {
    true
  }
}

// MARK: -

extension Trait where Self == ConditionTrait {
  /// Construct a condition trait that causes a test to be disabled if it
  /// returns `false`.
  ///
  /// - Parameters:
  ///   - condition: A closure containing the trait's custom condition logic. If
  ///     this closure returns `true`, the test is allowed to run. Otherwise,
  ///     the test is skipped.
  ///   - comment: An optional, user-specified comment describing this trait.
  ///   - sourceLocation: The source location of the trait.
  ///
  /// - Returns: An instance of ``ConditionTrait`` that will evaluate the
  ///   specified closure.
  //
  // @Comment {
  //   - Bug: `condition` cannot be `async` without making this function
  //     `async` even though `condition` is not evaluated locally.
  //     ([103037177](rdar://103037177))
  // }
  public static func enabled(
    if condition: @autoclosure @escaping @Sendable () throws -> Bool,
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) -> Self {
    Self(kind: .conditional(condition), comments: Array(comment), sourceLocation: sourceLocation)
  }

  /// Construct a condition trait that causes a test to be disabled if it
  /// returns `false`.
  ///
  /// - Parameters:
  ///   - comment: An optional, user-specified comment describing this trait.
  ///   - sourceLocation: The source location of the trait.
  ///   - condition: A closure containing the trait's custom condition logic. If
  ///     this closure returns `true`, the test is allowed to run. Otherwise,
  ///     the test is skipped.
  ///
  /// - Returns: An instance of ``ConditionTrait`` that will evaluate the
  ///   specified closure.
  public static func enabled(
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: @escaping @Sendable () async throws -> Bool
  ) -> Self {
    Self(kind: .conditional(condition), comments: Array(comment), sourceLocation: sourceLocation)
  }

  /// Construct a condition trait that disables a test unconditionally.
  ///
  /// - Parameters:
  ///   - comment: An optional, user-specified comment describing this trait.
  ///   - sourceLocation: The source location of the trait.
  ///
  /// - Returns: An instance of ``ConditionTrait`` that will always disable the
  ///   test to which it is added.
  public static func disabled(
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) -> Self {
    Self(kind: .unconditional(false), comments: Array(comment), sourceLocation: sourceLocation)
  }

  /// Construct a condition trait that causes a test to be disabled if it
  /// returns `true`.
  ///
  /// - Parameters:
  ///   - condition: A closure containing the trait's custom condition logic. If
  ///     this closure returns `false`, the test is allowed to run. Otherwise,
  ///     the test is skipped.
  ///   - comment: An optional, user-specified comment describing this trait.
  ///   - sourceLocation: The source location of the trait.
  ///
  /// - Returns: An instance of ``ConditionTrait`` that will evaluate the
  ///   specified closure.
  //
  // @Comment {
  //   - Bug: `condition` cannot be `async` without making this function
  //     `async` even though `condition` is not evaluated locally.
  //     ([103037177](rdar://103037177))
  // }
  public static func disabled(
    if condition: @autoclosure @escaping @Sendable () throws -> Bool,
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) -> Self {
    Self(kind: .conditional { !(try condition()) }, comments: Array(comment), sourceLocation: sourceLocation)
  }

  /// Construct a condition trait that causes a test to be disabled if it
  /// returns `true`.
  ///
  /// - Parameters:
  ///   - comment: An optional, user-specified comment describing this trait.
  ///   - sourceLocation: The source location of the trait.
  ///   - condition: A closure containing the trait's custom condition logic. If
  ///     this closure returns `false`, the test is allowed to run. Otherwise,
  ///     the test is skipped.
  ///
  /// - Returns: An instance of ``ConditionTrait`` that will evaluate the
  ///   specified closure.
  public static func disabled(
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: @escaping @Sendable () async throws -> Bool
  ) -> Self {
    Self(kind: .conditional { !(try await condition()) }, comments: Array(comment), sourceLocation: sourceLocation)
  }
}

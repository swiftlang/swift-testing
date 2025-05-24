//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type that allows transforming or filtering the issues recorded by a test.
///
/// Use this type to observe or customize the issue(s) recorded by the test this
/// trait is applied to. You can transform a recorded issue by copying it,
/// modifying one or more of its properties, and returning the copy. You can
/// observe recorded issues by returning them unmodified. Or you can suppress an
/// issue by either filtering it using ``Trait/filterIssues(_:)`` or returning
/// `nil` from the closure passed to ``Trait/transformIssues(_:)``.
///
/// When an instance of this trait is applied to a suite, it is recursively
/// inherited by all child suites and tests.
///
/// To add this trait to a test, use one of the following functions:
///
/// - ``Trait/transformIssues(_:)``
/// - ``Trait/filterIssues(_:)``
@_spi(Experimental)
public struct IssueHandlingTrait: TestTrait, SuiteTrait {
  /// A function which handles an issue and returns an optional replacement.
  ///
  /// - Parameters:
  ///   - issue: The issue to handle.
  ///
  /// - Returns: An issue to replace `issue`, or else `nil` if the issue should
  ///   not be recorded.
  fileprivate typealias Handler = @Sendable (_ issue: Issue) -> Issue?

  /// This trait's handler function.
  private var _handler: Handler

  fileprivate init(handler: @escaping Handler) {
    _handler = handler
  }

  /// Handle a specified issue.
  ///
  /// - Parameters:
  ///   - issue: The issue to handle.
  ///
  /// - Returns: An issue to replace `issue`, or else `nil` if the issue should
  ///   not be recorded.
  public func handleIssue(_ issue: Issue) -> Issue? {
    _handler(issue)
  }

  public var isRecursive: Bool {
    true
  }
}

extension IssueHandlingTrait: TestScoping {
  public func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
    // Provide scope for tests at both the suite and test case levels, but not
    // for the test function level. This avoids redundantly invoking the closure
    // twice, and potentially double-processing, issues recorded by test
    // functions.
    test.isSuite || testCase != nil ? self : nil
  }

  public func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
    try await provideScope(performing: function)
  }

  /// Provide scope for a specified function.
  ///
  /// - Parameters:
  ///   - function: The function to perform.
  ///
  /// This is a simplified version of ``provideScope(for:testCase:performing:)``
  /// which doesn't accept test or test case parameters. It's included so that
  /// a runner can invoke this trait's closure even when there is no test case,
  /// such as if a trait on a test function threw an error during `prepare(for:)`
  /// and caused an issue to be recorded for the test function. In that scenario,
  /// this trait still needs to be invoked, but its `scopeProvider(for:testCase:)`
  /// intentionally returns `nil` (see the comment in that method), so this
  /// function can be called instead to ensure this trait can still handle that
  /// issue.
  func provideScope(performing function: @Sendable () async throws -> Void) async throws {
    guard var configuration = Configuration.current else {
      preconditionFailure("Configuration.current is nil when calling \(#function). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    }

    configuration.eventHandler = { [oldConfiguration = configuration] event, context in
      guard case let .issueRecorded(issue) = event.kind else {
        oldConfiguration.eventHandler(event, context)
        return
      }

      // Use the original configuration's event handler when invoking the
      // transformer to avoid infinite recursion if the transformer itself
      // records new issues. This means only issue handling traits whose scope
      // is outside this one will be allowed to handle such issues.
      let newIssue = Configuration.withCurrent(oldConfiguration) {
        handleIssue(issue)
      }

      if let newIssue {
        var event = event
        event.kind = .issueRecorded(newIssue)
        oldConfiguration.eventHandler(event, context)
      }
    }

    try await Configuration.withCurrent(configuration, perform: function)
  }
}

@_spi(Experimental)
extension Trait where Self == IssueHandlingTrait {
  /// Constructs an trait that transforms issues recorded by a test.
  ///
  /// - Parameters:
  ///   - transformer: The closure called for each issue recorded by the test
  ///     this trait is applied to. It is passed a recorded issue, and returns
  ///     an optional issue to replace the passed-in one.
  ///
  /// - Returns: An instance of ``IssueHandlingTrait`` that transforms issues.
  ///
  /// The `transformer` closure is called synchronously each time an issue is
  /// recorded by the test this trait is applied to. The closure is passed the
  /// recorded issue, and if it returns a non-`nil` value, that will be recorded
  /// instead of the original. Otherwise, if the closure returns `nil`, the
  /// issue is suppressed and will not be included in the results.
  ///
  /// The `transformer` closure may be called more than once if the test records
  /// multiple issues. If more than one instance of this trait is applied to a
  /// test (including via inheritance from a containing suite), the `transformer`
  /// closure for each instance will be called in right-to-left, innermost-to-
  /// outermost order, unless `nil` is returned, which will skip invoking the
  /// remaining traits' closures.
  ///
  /// Within `transformer`, you may access the current test or test case (if any)
  /// using ``Test/current`` ``Test/Case/current``, respectively. You may also
  /// record new issues, although they will only be handled by issue handling
  /// traits which precede this trait or were inherited from a containing suite.
  public static func transformIssues(_ transformer: @escaping @Sendable (Issue) -> Issue?) -> Self {
    Self(handler: transformer)
  }

  /// Constructs a trait that filters issues recorded by a test.
  ///
  /// - Parameters:
  ///   - isIncluded: The predicate with which to filter issues recorded by the
  ///     test this trait is applied to. It is passed a recorded issue, and
  ///     should return `true` if the issue should be included, or `false` if it
  ///     should be suppressed.
  ///
  /// - Returns: An instance of ``IssueHandlingTrait`` that filters issues.
  ///
  /// The `isIncluded` closure is called synchronously each time an issue is
  /// recorded by the test this trait is applied to. The closure is passed the
  /// recorded issue, and if it returns `true`, the issue will be preserved in
  /// the test results. Otherwise, if the closure returns `false`, the issue
  /// will not be included in the test results.
  ///
  /// The `isIncluded` closure may be called more than once if the test records
  /// multiple issues. If more than one instance of this trait is applied to a
  /// test (including via inheritance from a containing suite), the `isIncluded`
  /// closure for each instance will be called in right-to-left, innermost-to-
  /// outermost order, unless `false` is returned, which will skip invoking the
  /// remaining traits' closures.
  ///
  /// Within `isIncluded`, you may access the current test or test case (if any)
  /// using ``Test/current`` ``Test/Case/current``, respectively. You may also
  /// record new issues, although they will only be handled by issue handling
  /// traits which precede this trait or were inherited from a containing suite.
  public static func filterIssues(_ isIncluded: @escaping @Sendable (Issue) -> Bool) -> Self {
    Self { issue in
      isIncluded(issue) ? issue : nil
    }
  }
}

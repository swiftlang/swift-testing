//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Synchronization)
private import Synchronization
#endif

/// A type that represents an active ``withExpectedIssue(_:isIntermittent:sourceLocation:_:matching:)``
/// call.
///
/// When a test function calls ``withExpectedIssue(_:isIntermittent:sourceLocation:_:matching:)``,
/// an instance of this type is pushed onto the task-local stack. Any ``Issue``
/// recorded while this scope is active that is matched by its ``matcher`` is
/// suppressed (not recorded as a test failure) and captured for the caller to
/// inspect.
struct ExpectedIssueScope: Sendable {
  /// A function which determines whether a given issue matches this scope.
  ///
  /// - Parameters:
  ///   - issue: The issue to evaluate.
  ///
  /// - Returns: `true` if the issue is the one expected by this scope,
  ///   `false` otherwise.
  typealias Matcher = @Sendable (_ issue: Issue) -> Bool

  /// The matcher function for this expected issue scope.
  var matcher: Matcher

  /// The number of issues this scope has suppressed (matched).
  fileprivate let matchCounter: Allocated<Atomic<Int>>

  /// The first issue captured by this scope, if any.
  fileprivate let capturedIssue: Allocated<Mutex<Issue?>>

  /// Create a new ``ExpectedIssueScope`` with the given issue matcher.
  ///
  /// - Parameters:
  ///   - issueMatcher: A function to invoke when an issue occurs that is used
  ///     to determine if the issue is the expected one.
  init(issueMatcher: @escaping KnownIssueMatcher) {
    let matchCounter = Allocated(Atomic(0))
    let capturedIssue = Allocated(Mutex<Issue?>())
    self.matchCounter = matchCounter
    self.capturedIssue = capturedIssue
    matcher = { issue in
      guard issueMatcher(issue) else {
        return false
      }
      matchCounter.value.add(1, ordering: .sequentiallyConsistent)
      capturedIssue.value.withLock { stored in
        if stored == nil {
          stored = issue
        }
      }
      return true
    }
  }

  /// The active expected issue scope for the current task, if any.
  ///
  /// If there is no call to
  /// ``withExpectedIssue(_:isIntermittent:sourceLocation:_:matching:)``
  /// executing on the current task, the value of this property is `nil`.
  @TaskLocal
  static var current: ExpectedIssueScope?
}

// MARK: -

/// Invoke a function that is expected to record at least one issue during
/// its execution.
///
/// - Parameters:
///   - comment: An optional comment describing the expected issue.
///   - isIntermittent: Whether or not the expected issue occurs intermittently.
///     If this argument is `true` and no issue occurs, no secondary issue is
///     recorded.
///   - sourceLocation: The source location to which any recorded issues should
///     be attributed.
///   - body: The function to invoke.
///   - issueMatcher: A function to invoke when an issue occurs that is used to
///     determine if it is the expected issue. By default, all issues match.
///
/// - Returns: The first ``Issue`` that was matched and suppressed by this
///   function, or `nil` if no matching issue was recorded. The returned
///   issue is provided so that callers may inspect its content (e.g. its
///   ``Issue/comments`` or ``Issue/kind``).
///
/// Use this function when testing a custom assertion helper or testing utility
/// to verify that it correctly records an ``Issue``. Unlike
/// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``, which
/// implies a bug that is expected to be fixed in the future,
/// `withExpectedIssue` expresses that recording an issue is the **correct and
/// intended behavior** of the code under test.
///
/// For example, suppose you have written a custom assertion helper:
///
/// ```swift
/// func assertIsPositive(_ value: Int, sourceLocation: SourceLocation = #Testing::sourceLocation) {
///   if value <= 0 {
///     Issue.record("Expected a positive value, but got \(value)", sourceLocation: sourceLocation)
///   }
/// }
/// ```
///
/// You can test that this helper correctly records an issue using
/// `withExpectedIssue`:
///
/// ```swift
/// @Test func assertIsPositiveRecordsIssueForNegativeValue() {
///   let issue = withExpectedIssue {
///     assertIsPositive(-1)
///   }
///   #expect(issue?.comments.first?.rawValue.contains("positive") == true)
/// }
/// ```
///
/// If `body` does not record any matching issue, and `isIntermittent` is
/// `false`, an ``Issue`` of kind ``Issue/Kind/knownIssueNotRecorded`` is
/// recorded for the current test, indicating that the expected issue was
/// missing.
///
/// - Note: `issueMatcher` may be invoked more than once for the same issue.
@_spi(Experimental)
@discardableResult
public func withExpectedIssue(
  _ comment: Comment? = nil,
  isIntermittent: Bool = false,
  sourceLocation: SourceLocation = #Testing::sourceLocation,
  _ body: () throws -> Void,
  matching issueMatcher: @escaping KnownIssueMatcher = { _ in true }
) -> Issue? {
  let scope = ExpectedIssueScope(issueMatcher: issueMatcher)
  ExpectedIssueScope.$current.withValue(scope) {
    do {
      try body()
    } catch is ExpectationFailedError {
      // ExpectationFailedError is thrown by #require() when a condition
      // fails. The expectation checking function already records its own
      // issue, which will be matched by the scope's matcher if applicable.
    } catch {
      // For other thrown errors, create an issue and run it through the
      // scope's matcher. If it matches, it is suppressed; otherwise it is
      // recorded normally.
      let sourceContext = SourceContext(backtrace: Backtrace(forFirstThrowOf: error), sourceLocation: sourceLocation)
      let issue = Issue(kind: .errorCaught(error), comments: [], sourceContext: sourceContext)
      if !scope.matcher(issue) {
        issue.record()
      }
    }
  }
  if !isIntermittent && scope.matchCounter.value.load(ordering: .sequentiallyConsistent) == 0 {
    let issue = Issue(
      kind: .knownIssueNotRecorded,
      comments: Array(comment),
      sourceContext: .init(backtrace: nil, sourceLocation: sourceLocation)
    )
    issue.record()
  }
  return scope.capturedIssue.value.withLock { $0 }
}

/// Invoke an async function that is expected to record at least one issue
/// during its execution.
///
/// - Parameters:
///   - comment: An optional comment describing the expected issue.
///   - isIntermittent: Whether or not the expected issue occurs intermittently.
///     If this argument is `true` and no issue occurs, no secondary issue is
///     recorded.
///   - isolation: The actor to which `body` is isolated, if any.
///   - sourceLocation: The source location to which any recorded issues should
///     be attributed.
///   - body: The async function to invoke.
///   - issueMatcher: A function to invoke when an issue occurs that is used to
///     determine if it is the expected issue. By default, all issues match.
///
/// - Returns: The first ``Issue`` that was matched and suppressed by this
///   function, or `nil` if no matching issue was recorded. The returned
///   issue is provided so that callers may inspect its content (e.g. its
///   ``Issue/comments`` or ``Issue/kind``).
///
/// Use this function when testing a custom assertion helper or testing utility
/// to verify that it correctly records an ``Issue``. Unlike
/// ``withKnownIssue(_:isIntermittent:isolation:sourceLocation:_:when:matching:)``,
/// which implies a bug that is expected to be fixed in the future,
/// `withExpectedIssue` expresses that recording an issue is the **correct and
/// intended behavior** of the code under test.
///
/// - Note: `issueMatcher` may be invoked more than once for the same issue.
@_spi(Experimental)
@discardableResult
public func withExpectedIssue(
  _ comment: Comment? = nil,
  isIntermittent: Bool = false,
  isolation: isolated (any Actor)? = #isolation,
  sourceLocation: SourceLocation = #Testing::sourceLocation,
  _ body: () async throws -> Void,
  matching issueMatcher: @escaping KnownIssueMatcher = { _ in true }
) async -> Issue? {
  let scope = ExpectedIssueScope(issueMatcher: issueMatcher)
  await ExpectedIssueScope.$current.withValue(scope) {
    do {
      try await body()
    } catch is ExpectationFailedError {
      // ExpectationFailedError is thrown by #require() when a condition
      // fails. The expectation checking function already records its own
      // issue, which will be matched by the scope's matcher if applicable.
    } catch {
      // For other thrown errors, create an issue and run it through the
      // scope's matcher. If it matches, it is suppressed; otherwise it is
      // recorded normally.
      let sourceContext = SourceContext(backtrace: Backtrace(forFirstThrowOf: error), sourceLocation: sourceLocation)
      let issue = Issue(kind: .errorCaught(error), comments: [], sourceContext: sourceContext)
      if !scope.matcher(issue) {
        issue.record()
      }
    }
  }
  if !isIntermittent && scope.matchCounter.value.load(ordering: .sequentiallyConsistent) == 0 {
    let issue = Issue(
      kind: .knownIssueNotRecorded,
      comments: Array(comment),
      sourceContext: .init(backtrace: nil, sourceLocation: sourceLocation)
    )
    issue.record()
  }
  return scope.capturedIssue.value.withLock { $0 }
}

//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type that can be used to determine if an issue is a known issue.
///
/// A stack of these is stored in `Issue.currentKnownIssueContext`. The stack
/// is mutated by calls to `withKnownIssue()`.
struct KnownIssueContext: Sendable {
  /// Determine if an issue is known to this context or any of its ancestor
  /// contexts.
  ///
  /// Returns `nil` if the issue is not known.
  var match: @Sendable (Issue) -> Match?
  /// The number of issues this context and its ancestors have matched.
  let matchCounter: Locked<Int>

  struct Match {
    /// The comment that was passed to the `withKnownIssue()` call that matched the issue.
    var comment: Comment?
  }

  /// Create a new ``KnownIssueContext`` by combining a new issue matcher with
  /// any previously-set context.
  ///
  /// - Parameters:
  ///   - parent: The context that should be checked next if `issueMatcher`
  ///     fails to match an issue.
  ///   - issueMatcher: A function to invoke when an issue occurs that is used
  ///     to determine if the issue is known to occur.
  ///   - comment: Any comment to be associated with issues matched by
  ///     `issueMatcher`.
  /// - Returns: A new instance of ``KnownIssueContext``.
  init(parent: KnownIssueContext?, issueMatcher: @escaping KnownIssueMatcher, comment: Comment?) {
    let matchCounter = Locked(rawValue: 0)
    self.matchCounter = matchCounter
    match = { issue in
      let match = if issueMatcher(issue) {
        Match(comment: comment)
      } else {
        parent?.match(issue)
      }
      if match != nil {
        matchCounter.increment()
      }
      return match
    }
  }
}

/// Check if an error matches using an issue-matching function, and throw it if
/// it does not.
///
/// - Parameters:
///   - error: The error to test.
///   - issueMatcher: A function to which `error` is passed (after boxing it in
///     an instance of ``Issue``) to determine if it is known to occur.
///   - comment: An optional comment to apply to any issues generated by this
///     function.
///   - sourceLocation: The source location to which the issue should be
///     attributed.
private func _matchError(_ error: any Error, using issueContext: KnownIssueContext, comment: Comment?, sourceLocation: SourceLocation) throws {
  let sourceContext = SourceContext(backtrace: Backtrace(forFirstThrowOf: error), sourceLocation: sourceLocation)
  var issue = Issue(kind: .errorCaught(error), comments: Array(comment), sourceContext: sourceContext)
  if let match = issueContext.match(issue) {
    // It's a known issue, so mark it as such before recording it.
    issue.markAsKnown(comment: match.comment)
    issue.record()
  } else {
    // Rethrow the error, allowing the caller to catch it or for it to propagate
    // to the runner to record it as an issue.
    throw error
  }
}

/// Handle any miscounts by the specified match counter.
///
/// - Parameters:
///   - matchCounter: The counter responsible for tracking the number of matches
///     found by an issue matcher.
///   - comment: An optional comment to apply to any issues generated by this
///     function.
///   - sourceLocation: The source location to which the issue should be
///     attributed.
private func _handleMiscount(by matchCounter: Locked<Int>, comment: Comment?, sourceLocation: SourceLocation) {
  if matchCounter.rawValue == 0 {
    let issue = Issue(
      kind: .knownIssueNotRecorded,
      comments: Array(comment),
      sourceContext: .init(backtrace: nil, sourceLocation: sourceLocation)
    )
    issue.record()
  }
}

// MARK: -

/// A function that is used to match known issues.
///
/// - Parameters:
///   - issue: The issue to match.
///
/// - Returns: Whether or not `issue` is known to occur.
public typealias KnownIssueMatcher = @Sendable (_ issue: Issue) -> Bool

/// Invoke a function that has a known issue that is expected to occur during
/// its execution.
///
/// - Parameters:
///   - comment: An optional comment describing the known issue.
///   - isIntermittent: Whether or not the known issue occurs intermittently. If
///     this argument is `true` and the known issue does not occur, no secondary
///     issue is recorded.
///   - sourceLocation: The source location to which any recorded issues should
///     be attributed.
///   - body: The function to invoke.
///
/// Use this function when a test is known to record one or more issues that
/// should not cause the test to fail. For example:
///
/// ```swift
/// @Test func example() {
///   withKnownIssue {
///     try flakyCall()
///   }
/// }
/// ```
///
/// Because all errors thrown by `body` are caught as known issues, this
/// function is not throwing. If only some errors or issues are known to occur
/// while others should continue to cause test failures, use
/// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``
/// instead.
///
/// ## See Also
///
/// - <doc:known-issues>
public func withKnownIssue(
  _ comment: Comment? = nil,
  isIntermittent: Bool = false,
  sourceLocation: SourceLocation = #_sourceLocation,
  _ body: () throws -> Void
) {
  try? withKnownIssue(comment, isIntermittent: isIntermittent, sourceLocation: sourceLocation, body, matching: { _ in true })
}

/// Invoke a function that has a known issue that is expected to occur during
/// its execution.
///
/// - Parameters:
///   - comment: An optional comment describing the known issue.
///   - isIntermittent: Whether or not the known issue occurs intermittently. If
///     this argument is `true` and the known issue does not occur, no secondary
///     issue is recorded.
///   - sourceLocation: The source location to which any recorded issues should
///     be attributed.
///   - body: The function to invoke.
///   - precondition: A function that determines if issues are known to occur
///     during the execution of `body`. If this function returns `true`,
///     encountered issues that are matched by `issueMatcher` are considered to
///     be known issues; if this function returns `false`, `issueMatcher` is not
///     called and they are treated as unknown.
///   - issueMatcher: A function to invoke when an issue occurs that is used to
///     determine if the issue is known to occur. By default, all issues match.
///
/// - Throws: Whatever is thrown by `body`, unless it is matched by
///   `issueMatcher`.
///
/// Use this function when a test is known to record one or more issues that
/// should not cause the test to fail, or if a precondition affects whether
/// issues are known to occur. For example:
///
/// ```swift
/// @Test func example() throws {
///   try withKnownIssue {
///     try flakyCall()
///   } when: {
///     callsAreFlakyOnThisPlatform()
///   } matching: { issue in
///     issue.error is FileNotFoundError
///   }
/// }
/// ```
///
/// It is not necessary to specify both `precondition` and `issueMatcher` if
/// only one is relevant. If all errors and issues should be considered known
/// issues, use ``withKnownIssue(_:isIntermittent:sourceLocation:_:)``
/// instead.
///
/// - Note: `issueMatcher` may be invoked more than once for the same issue.
///
/// ## See Also
///
/// - <doc:known-issues>
public func withKnownIssue(
  _ comment: Comment? = nil,
  isIntermittent: Bool = false,
  sourceLocation: SourceLocation = #_sourceLocation,
  _ body: () throws -> Void,
  when precondition: () -> Bool = { true },
  matching issueMatcher: @escaping KnownIssueMatcher = { _ in true }
) rethrows {
  guard precondition() else {
    return try body()
  }
  let issueContext = KnownIssueContext(parent: Issue.currentKnownIssueContext, issueMatcher: issueMatcher, comment: comment)
  defer {
    if !isIntermittent {
      _handleMiscount(by: issueContext.matchCounter, comment: comment, sourceLocation: sourceLocation)
    }
  }
  try Issue.$currentKnownIssueContext.withValue(issueContext) {
    do {
      try body()
    } catch {
      try _matchError(error, using: issueContext, comment: comment, sourceLocation: sourceLocation)
    }
  }
}

/// Invoke a function that has a known issue that is expected to occur during
/// its execution.
///
/// - Parameters:
///   - comment: An optional comment describing the known issue.
///   - isIntermittent: Whether or not the known issue occurs intermittently. If
///     this argument is `true` and the known issue does not occur, no secondary
///     issue is recorded.
///   - isolation: The actor to which `body` is isolated, if any.
///   - sourceLocation: The source location to which any recorded issues should
///     be attributed.
///   - body: The function to invoke.
///
/// Use this function when a test is known to record one or more issues that
/// should not cause the test to fail. For example:
///
/// ```swift
/// @Test func example() {
///   await withKnownIssue {
///     try await flakyCall()
///   }
/// }
/// ```
///
/// Because all errors thrown by `body` are caught as known issues, this
/// function is not throwing. If only some errors or issues are known to occur
/// while others should continue to cause test failures, use
/// ``withKnownIssue(_:isIntermittent:isolation:sourceLocation:_:when:matching:)``
/// instead.
///
/// ## See Also
///
/// - <doc:known-issues>
public func withKnownIssue(
  _ comment: Comment? = nil,
  isIntermittent: Bool = false,
  isolation: isolated (any Actor)? = #isolation,
  sourceLocation: SourceLocation = #_sourceLocation,
  _ body: () async throws -> Void
) async {
  try? await withKnownIssue(comment, isIntermittent: isIntermittent, isolation: isolation, sourceLocation: sourceLocation, body, matching: { _ in true })
}

/// Invoke a function that has a known issue that is expected to occur during
/// its execution.
///
/// - Parameters:
///   - comment: An optional comment describing the known issue.
///   - isIntermittent: Whether or not the known issue occurs intermittently. If
///     this argument is `true` and the known issue does not occur, no secondary
///     issue is recorded.
///   - isolation: The actor to which `body` is isolated, if any.
///   - sourceLocation: The source location to which any recorded issues should
///     be attributed.
///   - body: The function to invoke.
///   - precondition: A function that determines if issues are known to occur
///     during the execution of `body`. If this function returns `true`,
///     encountered issues that are matched by `issueMatcher` are considered to
///     be known issues; if this function returns `false`, `issueMatcher` is not
///     called and they are treated as unknown.
///   - issueMatcher: A function to invoke when an issue occurs that is used to
///     determine if the issue is known to occur. By default, all issues match.
///
/// - Throws: Whatever is thrown by `body`, unless it is matched by
///   `issueMatcher`.
///
/// Use this function when a test is known to record one or more issues that
/// should not cause the test to fail, or if a precondition affects whether
/// issues are known to occur. For example:
///
/// ```swift
/// @Test func example() async throws {
///   try await withKnownIssue {
///     try await flakyCall()
///   } when: {
///     callsAreFlakyOnThisPlatform()
///   } matching: { issue in
///     issue.error is FileNotFoundError
///   }
/// }
/// ```
///
/// It is not necessary to specify both `precondition` and `issueMatcher` if
/// only one is relevant. If all errors and issues should be considered known
/// issues, use ``withKnownIssue(_:isIntermittent:isolation:sourceLocation:_:when:matching:)``
/// instead.
///
/// - Note: `issueMatcher` may be invoked more than once for the same issue.
///
/// ## See Also
///
/// - <doc:known-issues>
public func withKnownIssue(
  _ comment: Comment? = nil,
  isIntermittent: Bool = false,
  isolation: isolated (any Actor)? = #isolation,
  sourceLocation: SourceLocation = #_sourceLocation,
  _ body: () async throws -> Void,
  when precondition: () async -> Bool = { true },
  matching issueMatcher: @escaping KnownIssueMatcher = { _ in true }
) async rethrows {
  guard await precondition() else {
    return try await body()
  }
  let issueContext = KnownIssueContext(parent: Issue.currentKnownIssueContext, issueMatcher: issueMatcher, comment: comment)
  defer {
    if !isIntermittent {
      _handleMiscount(by: issueContext.matchCounter, comment: comment, sourceLocation: sourceLocation)
    }
  }
  try await Issue.$currentKnownIssueContext.withValue(issueContext) {
    do {
      try await body()
    } catch {
      try _matchError(error, using: issueContext, comment: comment, sourceLocation: sourceLocation)
    }
  }
}

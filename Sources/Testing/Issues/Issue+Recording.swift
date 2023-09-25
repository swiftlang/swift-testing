//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Issue {
  /// The known issue matcher, as set by `withKnownIssue()`, associated with the
  /// current task.
  ///
  /// If there is no call to `withKnownIssue()` executing on the current task,
  /// the value of this property is `nil`.
  @TaskLocal
  static var currentKnownIssueMatcher: KnownIssueMatcher?

  /// Record a new issue with the specified properties.
  ///
  /// - Parameters:
  ///   - kind: The kind of issue.
  ///   - comments: An array of comments describing the issue. This array may be
  ///     empty.
  ///   - backtrace: The backtrace of the issue, if available. This value is
  ///     used to construct an instance of ``SourceContext``.
  ///   - sourceLocation: The source location of the issue. This value is used
  ///     to construct an instance of ``SourceContext``.
  ///   - configuration: The test configuration to use when recording the issue.
  ///     The default value is ``Configuration/current``.
  ///
  /// - Returns: The issue that was recorded.
  @discardableResult
  static func record(_ kind: Kind, comments: [Comment], backtrace: Backtrace?, sourceLocation: SourceLocation, configuration: Configuration? = nil) -> Issue {
    let sourceContext = SourceContext(backtrace: backtrace, sourceLocation: sourceLocation)
    return record(kind, comments: comments, sourceContext: sourceContext, configuration: configuration)
  }

  /// Record a new issue with the specified properties.
  ///
  /// - Parameters:
  ///   - kind: The kind of issue.
  ///   - comments: An array of comments describing the issue. This array may be
  ///     empty.
  ///   - sourceContext: The source context of the issue.
  ///   - configuration: The test configuration to use when recording the issue.
  ///     The default value is ``Configuration/current``.
  ///
  /// - Returns: The issue that was recorded.
  @discardableResult
  static func record(_ kind: Kind, comments: [Comment], sourceContext: SourceContext, configuration: Configuration? = nil) -> Issue {
    let issue = Issue(kind: kind, comments: comments, sourceContext: sourceContext)
    issue.record(configuration: configuration)
    return issue
  }

  /// Record this issue by wrapping it in an ``Event`` and passing it to the
  /// current event handler.
  ///
  /// - Parameters:
  ///   - configuration: The test configuration to use when recording the issue.
  ///     The default value is ``Configuration/current``.
  func record(configuration: Configuration? = nil) {
    // If this issue matches via the known issue matcher, set a copy of it to be
    // known and record the copy instead.
    if !isKnown, let issueMatcher = Self.currentKnownIssueMatcher, issueMatcher(self) {
      var selfCopy = self
      selfCopy.isKnown = true
      return selfCopy.record(configuration: configuration)
    }

    Event(.issueRecorded(self)).post(configuration: configuration)
  }

  /// Record an issue when a running test fails unexpectedly.
  ///
  /// - Parameters:
  ///   - comment: A comment describing the expectation.
  ///
  /// - Returns: The issue that was recorded.
  ///
  /// Use this function if, while running a test, an issue occurs that cannot be
  /// represented as an expectation (using the ``expect(_:_:sourceLocation:)``
  /// or ``require(_:_:sourceLocation:)-6lago`` macros.)
  @discardableResult public static func record(
    _ comment: Comment? = nil,
    fileID: String = #fileID,
    filePath: StaticString = #filePath,
    line: Int = #line,
    column: Int = #column
  ) -> Self {
    let sourceLocation = SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
    let sourceContext = SourceContext(backtrace: .current(), sourceLocation: sourceLocation)
    let issue = Issue(kind: .unconditional, comments: Array(comment), sourceContext: sourceContext)
    issue.record()
    return issue
  }

  /// Record a new issue when a running test unexpectedly catches an error.
  ///
  /// - Parameters:
  ///   - error: The error that caused the issue.
  ///   - comment: A comment describing the expectation.
  ///
  /// - Returns: The issue that was recorded.
  ///
  /// This function can be used if an unexpected error is caught while running a
  /// test and it should be treated as a test failure. If an error is thrown
  /// from a test function, it is automatically recorded as an issue and this
  /// function does not need to be used.
  @discardableResult public static func record(
    _ error: any Error,
    _ comment: Comment? = nil,
    fileID: String = #fileID,
    filePath: StaticString = #filePath,
    line: Int = #line,
    column: Int = #column
  ) -> Self {
    let sourceLocation = SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
    let backtrace = Backtrace(forFirstThrowOf: error) ?? Backtrace.current()
    let sourceContext = SourceContext(backtrace: backtrace, sourceLocation: sourceLocation)
    let issue = Issue(kind: .errorCaught(error), comments: Array(comment), sourceContext: sourceContext)
    issue.record()
    return issue
  }
}

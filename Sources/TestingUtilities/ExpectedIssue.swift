//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

public import Testing

/// Invoke a function that is expected to record at least one issue during its
/// execution. Expected issues will not be sent to the rest of the testing
/// library.
///
/// - Parameters:
///   - body: The function to invoke.
///   - issueMatcher: A function to invoke when an issue occurs that is used to
///     determine if the issue is expected, utilizing `#expect` and `#require`
///     to indicate that the issue is expected.
///   - additionalMatchers: Additional matcher functions, which are used to
///     indicate multiple issues are expected.
///
/// Library authors use this function to validate that code correctly records
/// the expected issues. For every expected issue, there must be an equivalent
/// matcher closure that captures that issue. Matcher closures may be evaluated
/// multiple times, and the Testing Library will attempt to match recorded
/// issues to the most appropriate matcher.
///
/// Test authors should consider using
/// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``.
public func withExpectedIssue(
  sourceLocation: SourceLocation = #Testing::sourceLocation,
  _ body: () throws -> Void,
  matching matcher: @Sendable @escaping (Issue) throws -> Void,
  _ additionalMatchers: @Sendable (Issue) throws -> Void...
) {
  Testing.withExpectedIssue(
    sourceLocation: sourceLocation,
    body,
    matching: [matcher] + additionalMatchers
  )
}

/// Invoke a function that is expected to record at least one issue during its
/// execution. Expected issues will not be sent to the rest of the testing
/// library.
///
/// - Parameters:
///   - body: The function to invoke.
///   - issueMatcher: A function to invoke when an issue occurs that is used to
///     determine if the issue is expected, utilizing `#expect` and `#require`
///     to indicate that the issue is expected.
///   - additionalMatchers: Additional matcher functions, which are used to
///     indicate multiple issues are expected.
///
/// Library authors use this function to validate that code correctly records
/// the expected issues. For every expected issue, there must be an equivalent
/// matcher closure that captures that issue. Matcher closures may be evaluated
/// multiple times, and the Testing Library will attempt to match recorded
/// issues to the most appropriate matcher.
///
/// Test authors should consider using
/// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``.
package func withExpectedIssue(
  sourceLocation: SourceLocation = #Testing::sourceLocation,
  _ body: sending @isolated(any) () async throws -> Void,
  matching matcher: @Sendable @escaping (Issue) throws -> Void,
  _ additionalMatchers: @Sendable (Issue) throws -> Void...
) async {
  await Testing.withExpectedIssue(
    sourceLocation: sourceLocation,
    body,
    matching: [matcher] + additionalMatchers
  )
}

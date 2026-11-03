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
//
///// Invoke a function, capture and return any issues recorded during its
///// execution. Issues captured will not be sent to the rest of the testing
///// library.
/////
///// - Parameters:
/////   - body: The function to invoke.
/////
///// Library authors use this function to capture and analyze any issues for
///// later analysis. This is particularly useful for verifying that test helpers
///// correctly record issues.
///// Test authors should consider using
///// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``.
//public func withIssueCapturing(
//  _ body: () throws -> Void
//) -> [Issue] {
//  Testing.withIssueCapturing(body)
//}
//
///// Invoke a function, capture and return any issues recorded during its
///// execution. Issues captured will not be sent to the rest of the testing
///// library.
/////
///// - Parameters:
/////   - body: The function to invoke.
/////
///// Library authors use this function to capture and analyze any issues for
///// later analysis. This is particularly useful for verifying that test helpers
///// correctly record issues.
///// Test authors should consider using
///// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``.
//public func withIssueCapturing(
//  _ body: sending @isolated(any) () async throws -> Void
//) async -> [Issue] {
//  await Testing.withIssueCapturing(body)
//}

/// Invoke a function, capture and return any issues recorded during its
/// execution. Issues captured will not be sent to the rest of the testing
/// library.
///
/// - Parameters:
///   - body: The function to invoke.
///   - issueMatcher: A function to invoke when an issue occurs that is used to
///     determine if the issue should be captured. By default, all issues match.
///
/// Library authors use this function to capture and analyze any issues for
/// later analysis. This is particularly useful for verifying that test helpers
/// correctly record issues.
/// Test authors should consider using
/// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``.
package func withIssueCapturing(
  _ body: () throws -> Void,
  matching issueMatcher: @escaping @Sendable (Issue) -> Bool = { _ in true }
) -> [Issue] {
  Testing.withIssueCapturing(body, matching: issueMatcher)
}

/// Invoke a function, capture and return any issues recorded during its
/// execution. Issues captured will not be sent to the rest of the testing
/// library.
///
/// - Parameters:
///   - body: The function to invoke.
///   - issueMatcher: A function to invoke when an issue occurs that is used to
///     determine if the issue should be captured. By default, all issues match.
///
/// Library authors use this function to capture and analyze any issues for
/// later analysis. This is particularly useful for verifying that test helpers
/// correctly record issues.
/// Test authors should consider using
/// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``.
package func withIssueCapturing(
  _ body: sending @isolated(any) () async throws -> Void,
  matching issueMatcher: @escaping @Sendable (Issue) -> Bool = { _ in true }
) async -> [Issue] {
  await Testing.withIssueCapturing(body, matching: issueMatcher)
}


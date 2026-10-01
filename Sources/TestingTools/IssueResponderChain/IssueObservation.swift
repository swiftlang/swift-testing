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

/// Invoke a function, and return any issues recorded during its execution.
/// Issues recorded will be sent to the next responder in the Issue Responder
/// Chain.
///
/// - Parameters:
///   - sourceLocation: The source location to which any recorded issues should
///     be attributed.
///   - body: The function to invoke.
///
/// Library authors use this function to capture and analyze any issues for
/// later analysis. This is particularly useful for verifying that test helpers
/// correctly record issues.
/// Test authors should consider using
/// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``.
public func observeIssues(
  sourceLocation: SourceLocation = #Testing::sourceLocation,
  _ body: () throws -> Void
) -> [Issue] {
  Testing.observeIssues(sourceLocation: sourceLocation, body)
}

/// Invoke a function, and return any issues recorded during its execution.
/// Issues recorded will be sent to the next responder in the Issue Responder
/// Chain.
///
/// - Parameters:
///   - sourceLocation: The source location to which any recorded issues should
///     be attributed.
///   - body: The function to invoke.
///
/// Library authors use this function to capture and analyze any issues for
/// later analysis. This is particularly useful for verifying that test helpers
/// correctly record issues.
/// Test authors should consider using
/// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``.
package func observeIssues(
  sourceLocation: SourceLocation = #Testing::sourceLocation,
  _ body: sending @isolated(any) () async throws -> Void
) async -> [Issue] {
  await Testing.observeIssues(sourceLocation: sourceLocation, body)
}

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

/// Add a new ``IssueResponder`` instance onto the current Issue Responder
/// Chain.
///
/// - Parameters:
///   - issueResponder: The ``IssueResponder`` to add onto the Issue Responder
///     Chain.
///   - body: The function to invoke with the issue responder added to the
///     chain.
///
/// - returns: Whatever is returned by `body`.
/// - throws: Whatever is thrown by `body`.
public func withIssueResponder<T>(
  _ issueResponder: any IssueResponder,
  body: () throws -> T
) rethrows -> T {
  try Testing.withIssueResponder(issueResponder, body: body)
}

/// Add a new ``IssueResponder`` instance onto the current Issue Responder
/// Chain.
///
/// - Parameters:
///   - issueResponder: The ``IssueResponder`` to add onto the Issue Responder
///     Chain.
///   - body: The function to invoke with the issue responder added to the
///     chain.
///
/// - returns: Whatever is returned by `body`.
/// - throws: Whatever is thrown by `body`.
public func withIssueResponder<T>(
  _ issueResponder: any IssueResponder,
  body: sending @isolated(any) () async throws -> sending T
) async rethrows -> sending T {
  try await Testing.withIssueResponder(issueResponder, body: body)
}

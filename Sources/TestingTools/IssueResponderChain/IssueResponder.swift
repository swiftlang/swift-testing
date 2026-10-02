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

/// A protocol for types in the Issue Responder Chain.
///
/// The types in the Issue Responder Chain receive and handle issues in the time
/// between where they are initially reported and before they are sent off to
/// the testing library's event system. Implementing an IssueResponder allows
/// you to observe, transform, or even block an issue from being sent up the
/// chain.
///
/// Use ``withIssueResponder(_:body:)`` to add your IssueResponder to the Issue
/// Responder Chain.
public protocol IssueResponder: Sendable {
  /// Handle and respond to the given issue.
  ///
  /// - Parameters:
  ///   - issue: The issue to handle or respond to.
  /// - Returns: The issue to send to the next responder in the chain. This can
  ///   be the same issue that was sent, a transformed issue, or even nil, to
  ///   indicate that the Issue Responder Chain should stop processing the
  ///   issue.
  func respond(to issue: Issue) -> Issue?
}

private struct AnyIssueResponder: Testing.IssueResponder {
  let wrapping: any TestingTools.IssueResponder
  func respond(to issue: Issue) -> Issue? {
    wrapping.respond(to: issue)
  }
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
  _ issueResponder: any TestingTools.IssueResponder,
  body: () throws -> T
) rethrows -> T {
  try Testing.withIssueResponder(
    AnyIssueResponder(wrapping: issueResponder),
    body: body
  )
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
  _ issueResponder: any TestingTools.IssueResponder,
  body: sending @isolated(any) () async throws -> sending T
) async rethrows -> sending T {
  try await Testing.withIssueResponder(
    AnyIssueResponder(wrapping: issueResponder),
    body: body
  )
}

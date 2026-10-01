//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Synchronization)
private import Synchronization
#endif

/// A protocol for types in the Issue Responder Chain.
///
/// The types in the Issue Responder Chain receive and handle issues in the time
/// between where they are initially reported and before they are sent off to
/// the testing library's event system. Implementing an IssueResponder allows
/// you to observe, transform, or even block an issue from being sent up the
/// chain.
///
/// Use ``withIssueResponder(_:body:)`` (available in the TestingTools module)
/// to add your IssueResponder to the Issue Responder Chain.
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

/// A link in the Issue Responder Chain.
///
/// The Issue Responder Chain is the system for handling issues between when
/// they are initially recorded (such as with `Issue.record`) and when they are
/// sent to the eventing system. The very last link in the Issue Responder Chain
/// is sending the issue to the eventing system.
package struct IssueResponderLink: Sendable {
  /// A closure referencing the parent, or previous link in the issue responder
  /// chain.
  let parent: @Sendable () -> IssueResponderLink?

  /// The ``IssueResponder`` wrapped by this type.
  let responder: any IssueResponder

  /// Create a new link in the IssueResponderChain
  ///
  /// - Parameters:
  ///   - parent: The now-previous link in the Issue Responder Chain.
  ///   - responder: The ``IssueResponder`` type to be wrapped by this link.
  init(
    parent: IssueResponderLink?,
    responder: any IssueResponder
  ) {
    self.parent = { parent }
    self.responder = responder
  }

  /// Compute and return the list of all ``IssueResponder``s in the current
  /// chain up to and including this link.
  ///
  /// - Returns: The list of issue responders in the current chain.
  package func chain() -> [any IssueResponder] {
    if let parent = parent() {
      return [self.responder] + parent.chain()
    } else {
      return [self.responder]
    }
  }

  /// The current last link in the Issue Responder Chain. If there hasn't been
  /// any calls to ``withIssueResponder(_:body:)`` executing on the current
  /// task, then this value is nil.
  @TaskLocal
  static var current: IssueResponderLink? = nil
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
package func withIssueResponder<T>(
  _ issueResponder: any IssueResponder,
  body: () throws -> T
) rethrows -> T {
  try IssueResponderLink.$current.withValue(
    IssueResponderLink(
      parent: IssueResponderLink.current,
      responder: issueResponder
    ),
    operation: body
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
package func withIssueResponder<T>(
  _ issueResponder: any IssueResponder,
  body: sending @isolated(any) () async throws -> sending T
) async rethrows -> sending T {
  try await IssueResponderLink.$current.withValue(
    IssueResponderLink(
      parent: IssueResponderLink.current,
      responder: issueResponder
    ),
    operation: {
      try await body()
    }
  )
}

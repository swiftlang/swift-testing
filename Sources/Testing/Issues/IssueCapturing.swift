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
internal import Synchronization
#endif

/// An ``IssueResponder`` for recording any matching issues that are sent to it
/// without making any modifications. Recorded issues are not sent to the next
/// responder in the issue responder chain.
struct CaptureIssuesResponder: IssueResponder {
  /// The list of issues recorded during execution.
  let issues = Allocated(Mutex([Issue]()))
  let issueMatcher: @Sendable (Issue) -> Bool

  /// Respond to the issue by recording it and stopping the issue from being
  /// sent to the next responder in the chain.
  func respond(to issue: Issue) -> Issue? {
    if issueMatcher(issue) {
      issues.value.withLock { $0.append(issue) }
      return nil
    } else {
      return issue
    }
  }
}

/// Create an ``Issue`` for the error and send it through the Issue Responder Chain.
///
/// - Parameters:
///   - error: The error to convert into an ``Issue``.
private func _recordError(
  _ error: any Error
) {
  // ExpectationFailedError is thrown by expectation checking functions to
  // indicate a condition evaluated to `false`. Those functions record their
  // own issue, so we don't need to create a new issue and attempt to match it.
  if error is ExpectationFailedError {
    return
  }

  Issue(for: error).record()
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
  _ body: () throws -> Void,
  matching issueMatcher: @escaping @Sendable (Issue) -> Bool = { _ in true }
) -> [Issue] {
  let responder = CaptureIssuesResponder(issueMatcher: issueMatcher)
  withIssueResponder(responder) {
    do {
      try body()
    } catch {
      _recordError(error)
    }
  }
  return responder.issues.value.withLock { $0 }
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
  let responder = CaptureIssuesResponder(issueMatcher: issueMatcher)
  await withIssueResponder(responder) {
    do {
      try await body()
    } catch {
      _recordError(error)
    }
  }
  return responder.issues.value.withLock { $0 }
}

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

/// An ``IssueResponder`` for transparently recording any issues that pass
/// through it without making any modifications.
///
/// Instances of `ObserveIssueResponder` are created whenever an
/// ``observeIssues(sourceLocation:_:)`` call is made. These are added to the
/// Issue Responder Chain and used to observe all issues emitted during the
/// `body` of the `observeIssues` call.
struct ObserveIssuesResponder: IssueResponder {
  /// The list of issues recorded during execution.
  let issues = Allocated(Mutex([Issue]()))

  /// Respond to the issue by recording it and sending it to the next responder
  /// in the chain.
  func respond(to issue: Issue) -> Issue? {
    issues.value.withLock { $0.append(issue) }
    return issue
  }
}

/// An ``IssueResponder`` for recording any issues that are sent to it without
/// making any modifications. `CaptureIssuesResponder` differs from
/// ``ObserveIssuesResponder`` in that it does not pass the issue on to the
/// next responder in the Issue Responder Chain.
struct CaptureIssuesResponder: IssueResponder {
  /// The list of issues recorded during execution.
  let issues = Allocated(Mutex([Issue]()))

  /// Respond to the issue by recording it and stopping the issue from being
  /// sent to the next responder in the chain.
  func respond(to issue: Issue) -> Issue? {
    issues.value.withLock { $0.append(issue) }
    return nil
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
/// execution. Issues captured will not be sent to the next responder in the
/// Issue Responder Chain.
///
/// - Parameters:
///   - body: The function to invoke.
///
/// Library authors use this function to capture and analyze any issues for
/// later analysis. This is particularly useful for verifying that test helpers
/// correctly record issues.
/// Test authors should consider using
/// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``.
package func captureIssues(
  _ body: () throws -> Void
) -> [Issue] {
  let responder = CaptureIssuesResponder()
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
/// execution. Issues captured will not be sent to the next responder in the
/// Issue Responder Chain.
///
/// - Parameters:
///   - body: The function to invoke.
///
/// Library authors use this function to capture and analyze any issues for
/// later analysis. This is particularly useful for verifying that test helpers
/// correctly record issues.
/// Test authors should consider using
/// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``.
package func captureIssues(
  _ body: sending @isolated(any) () async throws -> Void
) async -> [Issue] {
  let responder = CaptureIssuesResponder()
  await withIssueResponder(responder) {
    do {
      try await body()
    } catch {
      _recordError(error)
    }
  }
  return responder.issues.value.withLock { $0 }
}

/// Invoke a function, and return any issues recorded during its execution.
/// Issues recorded will be sent to the next responder in the Issue Responder
/// Chain.
///
/// - Parameters:
///   - body: The function to invoke.
///
/// Library authors use this function to capture and analyze any issues for
/// later analysis. This is particularly useful for verifying that test helpers
/// correctly record issues.
/// Test authors should consider using
/// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``.
package func observeIssues(
  _ body: () throws -> Void
) -> [Issue] {
  let responder = ObserveIssuesResponder()
  withIssueResponder(responder) {
    do {
      try body()
    } catch {
      _recordError(error)
    }
  }
  return responder.issues.value.withLock { $0 }
}

/// Invoke a function, and return any issues recorded during its execution.
/// Issues recorded will be sent to the next responder in the Issue Responder
/// Chain.
///
/// - Parameters:
///   - body: The function to invoke.
///
/// Library authors use this function to capture and analyze any issues for
/// later analysis. This is particularly useful for verifying that test helpers
/// correctly record issues.
/// Test authors should consider using
/// ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``.
package func observeIssues(
  _ body: sending @isolated(any) () async throws -> Void
) async -> [Issue] {
  let responder = ObserveIssuesResponder()
  await withIssueResponder(responder) {
    do {
      try await body()
    } catch {
      _recordError(error)
    }
  }
  return responder.issues.value.withLock { $0 }
}

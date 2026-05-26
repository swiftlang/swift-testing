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

extension Runner {
  /// A thread-safe set of test+case IDs that have recorded issues.
  /// This keeps track of tests that recorded an issue during a test repetition
  /// and is used by the repetition machinery to determine if an issue was recorded
  /// during a run.
  final class TestIssueRecorder: Sendable {
    /// A composite identifier uniquely naming a test case within a test.
    private struct _ID: Hashable {
      var testID: Test.ID
      var testCaseID: Test.Case.ID
    }

    /// The set of recorded issue identifiers, protected by a mutex.
    private let _ids = Mutex<Set<_ID>>([])

    /// Whether any issue has been recorded since the recorder was last cleared.
    var hasIssues: Bool {
      _ids.withLock { !$0.isEmpty }
    }

    /// Record that an issue was observed for a given test case.
    ///
    /// - Parameters:
    ///   - test: The ID of the test whose case recorded the issue.
    ///   - testCase: The ID of the test case which recorded the issue.
    func recordIssue(for test: Test.ID, testCase: Test.Case.ID) {
      _ids.withLock {
        _ = $0.insert(_ID(testID: test, testCaseID: testCase))
      }
    }

    /// Remove a recorded issue for a given test case, returning whether one was present.
    ///
    /// - Parameters:
    ///   - test: The ID of the test whose case should be consumed.
    ///   - testCase: The ID of the test case to consume.
    ///
    /// - Returns: `true` if an issue had been recorded for the specified test case
    ///   since the recorder was last cleared; otherwise `false`.
    func consumeIssue(for test: Test.ID, testCase: Test.Case.ID) -> Bool {
      _ids.withLock {
        $0.remove(_ID(testID: test, testCaseID: testCase)) != nil
      }
    }

    /// Remove all recorded issues from this recorder.
    func clear() {
      _ids.withLock { $0.removeAll() }
    }
  }

  /// Applies a repetition policy by running the provided body repeatedly until its
  /// continuation condition is satisfied.
  ///
  /// - Parameters:
  ///   - policy: The repetition policy to apply.
  ///   - body: The actual body of the function which must ultimately call into the test function.
  ///   - didRecordIssue: A closure passed by the caller to determine if an issue was recorded during
  ///     the test run.
  static func _applyRepetitionPolicy(
    _ policy: Configuration.RepetitionPolicy,
    perform body: () async -> Void,
    didRecordIssue: () -> Bool
  ) async {
    for iteration in 1...policy.maximumIterationCount {
      await Test.withCurrentIteration(iteration) {
        await body()
      }

      let recordedIssue = didRecordIssue()

      // Determine if the test plan should iterate again.
      let shouldContinue = switch policy.continuationCondition {
      case nil:
        true
      case .untilIssueRecorded:
        !recordedIssue
      case .whileIssueRecorded:
        recordedIssue
      }
      guard shouldContinue else {
        break
      }
    }
  }

  /// Wire this runner's configuration event handler through the given issue recorder
  /// so that recorded issues are tracked during a run.
  ///
  /// - Parameters:
  ///   - testIssueRecorder: The recorder to notify of any recorded issues.
  mutating func configureIssueRecordingEventHandling(testIssueRecorder: TestIssueRecorder) {
    configuration.eventHandler = { [oldEventHandler = configuration.eventHandler] event, context in
      if case .issueRecorded = event.kind, let testID = event.testID, let testCaseID = event.testCaseID {
        testIssueRecorder.recordIssue(for: testID, testCase: testCaseID)
      }

      oldEventHandler(event, context)
    }
  }
}

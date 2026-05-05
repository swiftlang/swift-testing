//
//  Runner+Repetition.swift
//  swift-testing
//
//  Created by Harlan Haskins on 5/5/26.
//

extension Runner {
  /// A thread-safe set of test+case IDs that have recorded issues.
  /// This keeps track of tests that recorded an issue during a test repetition
  /// and is used by the repetition machinery to determine if an issue was recorded
  /// during a run.
  final class TestIssueRecorder: Sendable {
    struct ID: Hashable {
      var testID: Test.ID
      var testCaseID: Test.Case.ID
    }
    let ids = Mutex<Set<ID>>([])

    var hasIssues: Bool {
      ids.withLock { !$0.isEmpty }
    }

    func recordIssue(for test: Test.ID, testCase: Test.Case.ID) {
      ids.withLock {
        _ = $0.insert(ID(testID: test, testCaseID: testCase))
      }
    }

    func consumeIssue(for test: Test.ID, testCase: Test.Case.ID) -> Bool {
      ids.withLock {
        $0.remove(ID(testID: test, testCaseID: testCase)) != nil
      }
    }

    func clear() {
      ids.withLock { $0.removeAll() }
    }
  }

  /// Applies the repetition policy specified in the current configuration by running the provided test case
  /// repeatedly until the continuation condition is satisfied.
  ///
  /// - Parameters:
  ///   - body: The actual body of the function which must ultimately call into the test function.
  ///   - didRecordIssue: A closure passed by the caller to determine if an issue was recorded during
  ///   the test run.
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

  mutating func configureIssueRecordingEventHandling(testIssueRecorder: TestIssueRecorder) {
    configuration.eventHandler = { [oldEventHandler = configuration.eventHandler] event, context in
      defer {
        oldEventHandler(event, context)
      }

      guard
        case .issueRecorded = event.kind,
        let testID = event.testID,
        let testCaseID = event.testCaseID
      else {
        return
      }

      testIssueRecorder.recordIssue(for: testID, testCase: testCaseID)
    }
  }
}

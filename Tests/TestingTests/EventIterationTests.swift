//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ForToolsIntegrationOnly) import Testing

#if !SWT_TARGET_OS_APPLE && canImport(Synchronization)
import Synchronization
#endif

@Suite("Event Iteration Tests")
struct EventIterationTests {
  /// Helper to verify that events of a given kind include iteration values
  private func verifyIterations(
    for eventKinds: [Event.Kind],
    repetitionPolicy: Configuration.RepetitionPolicy,
    expectedIterations: Int,
    testBody: @escaping @Sendable (Int) -> Void,
    location: SourceLocation = #_sourceLocation
  ) async {
    let recordedIteration = Mutex<Int>(0)

    await confirmation("Events received", expectedCount: expectedIterations * eventKinds.count, sourceLocation: location) { eventReceived in
      var configuration = Configuration()
      configuration.eventHandler = { event, context in
        if eventKinds.contains(where: { Self.matchesTestLifetimeEventKind($0, event.kind) }) {
          if let iteration = context.iteration {
            recordedIteration.withLock { $0 = iteration }
          }
          eventReceived()
        }
      }
      configuration.repetitionPolicy = repetitionPolicy

      await Test {
        testBody(recordedIteration.rawValue)
      }.run(configuration: configuration)

      // Verify all expected iterations were recorded
      let iteration = recordedIteration.rawValue
      #expect(iteration == expectedIterations, sourceLocation: location)
    }
  }

  private static func matchesTestLifetimeEventKind(_ expected: Event.Kind, _ actual: Event.Kind) -> Bool {
    switch (expected, actual) {
    case (.testStarted, .testStarted),
         (.testEnded, .testEnded),
         (.testCaseStarted, .testCaseStarted),
         (.testCaseEnded, .testCaseEnded):
      return true
    default:
      return false
    }
  }

  @Test
  func `testStarted and testEnded events include iteration in context`() async {
    await verifyIterations(
      for: [.testStarted, .testEnded],
      repetitionPolicy: .once,
      expectedIterations: 1
    ) { _ in
      // Do nothing, just pass
    }
  }

  @Test
  func `testCaseStarted and testCaseEnded events include iteration in context`() async {
    await verifyIterations(
      for: [.testCaseStarted, .testCaseEnded],
      repetitionPolicy: .repeating(maximumIterationCount: 5),
      expectedIterations: 5
    ) { _ in
      // Do nothing, just pass
    }
  }

  @Test(arguments: [
    (Configuration.RepetitionPolicy.once, 1),
    (.repeating(maximumIterationCount: 3), 3),
    (.repeating(.whileIssueRecorded, maximumIterationCount: 5), 3),
  ])
  func `event iteration is correct for different repetition policies`(
    policy: Configuration.RepetitionPolicy,
    expectedIterations: Int
  ) async {
    await verifyIterations(
      for: [.testCaseStarted, .testCaseEnded],
      repetitionPolicy: policy,
      expectedIterations: expectedIterations
    ) { iteration in
      #expect(iteration >= 3)
    }
  }
}

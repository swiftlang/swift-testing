//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

#if !SWT_TARGET_OS_APPLE && canImport(Synchronization)
import Synchronization
#endif

@Suite
struct TestCaseIterationTests {
  @Test("One iteration (default behavior)")
  func oneIteration() async {
    await confirmation("N iterations started") { started in
      await confirmation("N iterations ended") { ended in
        var configuration = Configuration()
        configuration.eventHandler = { event, _ in
          if case .testCaseStarted = event.kind {
            started()
          } else if case .testCaseEnded = event.kind {
            ended()
          }
        }
        configuration.repetitionPolicy = .once

        await Test {
        }.run(configuration: configuration)
      }
    }
  }

  @Test("Unconditional iteration")
  func unconditionalIteration() async {
    let iterationCount = 10
    await confirmation("N iterations started", expectedCount: iterationCount) { started in
      await confirmation("N iterations ended", expectedCount: iterationCount) { ended in
        var configuration = Configuration()
        configuration.eventHandler = { event, _ in
          if case .testCaseStarted = event.kind {
            started()
          } else if case .testCaseEnded = event.kind {
            ended()
          }
        }
        configuration.repetitionPolicy = .repeating(maximumIterationCount: iterationCount)

        await Test {
          if Bool.random() {
            #expect(Bool(false))
          }
        }.run(configuration: configuration)
      }
    }
  }

  @Test("Iteration until issue recorded")
  func iterationUntilIssueRecorded() async {
    let iterations = Atomic(0)
    let iterationCount = 10
    let iterationWithIssue = 5
    await confirmation("N iterations started", expectedCount: iterationWithIssue) { started in
      await confirmation("N iterations ended", expectedCount: iterationWithIssue) { ended in
        var configuration = Configuration()
        configuration.eventHandler = { event, context in
          guard let iteration = context.iteration else { return }
          if case .testCaseStarted = event.kind {
            iterations.store(iteration, ordering: .sequentiallyConsistent)
            started()
          } else if case .testCaseEnded = event.kind {
            ended()
          }
        }
        configuration.repetitionPolicy = .repeating(.untilIssueRecorded, maximumIterationCount: iterationCount)

        await Test {
          let iterations = iterations.load(ordering: .sequentiallyConsistent)
          #expect(iterations < iterationWithIssue)
        }.run(configuration: configuration)
      }
    }
  }

  @Test
  func `Iteration while issue recorded`() async {
    let iterations = Atomic(0)
    let iterationCount = 10
    let iterationWithoutIssue = 5
    await confirmation("N iterations started", expectedCount: iterationWithoutIssue) { started in
      await confirmation("N iterations ended", expectedCount: iterationWithoutIssue) { ended in
        var configuration = Configuration()
        configuration.eventHandler = { event, context in
          guard let iteration = context.iteration else { return }
          if case .testCaseStarted = event.kind {
            iterations.store(iteration, ordering: .sequentiallyConsistent)
            started()
          } else if case .testCaseEnded = event.kind {
            ended()
          }
        }
        configuration.repetitionPolicy = .repeating(.whileIssueRecorded, maximumIterationCount: iterationCount)

        await Test {
          let iterations = iterations.load(ordering: .sequentiallyConsistent)
          if iterations < iterationWithoutIssue {
            #expect(Bool(false))
          }
        }.run(configuration: configuration)
      }
    }
  }

  private enum IssueKind: Sendable {
    case failure
    case known
    case warning
  }

  @Test(arguments: [
    (.failure, .whileIssueRecorded, 3),
    (.known, .whileIssueRecorded, 1),
    (.warning, .whileIssueRecorded, 1),
    (.known, .untilIssueRecorded, 3),
    (.warning, .untilIssueRecorded, 3),
  ] as [(IssueKind, Configuration.RepetitionPolicy.ContinuationCondition, Int)])
  private func `Only failures cause repetition`(
    issueKind: IssueKind,
    continuingWhen: Configuration.RepetitionPolicy.ContinuationCondition,
    expectedIterationCount: Int
  ) async {
    let iterations = Atomic(0)
    var configuration = Configuration()
    configuration.repetitionPolicy = .repeating(continuingWhen, maximumIterationCount: 3)

    await Test {
      iterations.add(1, ordering: .sequentiallyConsistent)
      switch issueKind {
      case .failure:
        Issue.record("Failure")
      case .known:
        withKnownIssue {
          Issue.record("Expected defect")
        }
      case .warning:
        Issue.record("Warning", severity: .warning)
      }
    }.run(configuration: configuration)

    #expect(iterations.load(ordering: .sequentiallyConsistent) == expectedIterationCount)
  }

  // MARK: Encoded event ordering

  private func encodedEvents(for test: Test, encodeMessagesField: Bool = false) async -> [ABI.EncodedEvent<ABI.CurrentVersion>] {
    let events = Mutex<[ABI.EncodedEvent<ABI.CurrentVersion>]>()
    var configuration = Configuration()
    configuration.eventHandler = ABI.CurrentVersion.eventHandler(
      encodingMessagesField: encodeMessagesField
    ) { record in
      if case let .event(event) = record.kind {
        events.withLock {
          $0.append(event)
        }
      }
    }
    configuration.repetitionPolicy = .repeating(maximumIterationCount: 2)

    await test.run(configuration: configuration)
    return events.rawValue
  }

  private func assertEncodedEventKinds(
    _ test: Test,
    equals expected: [ABI.EncodedEvent<ABI.CurrentVersion>.Kind],
    sourceLocation: SourceLocation = #Testing::sourceLocation
  ) async {
    let events = await encodedEvents(for: test)
    let kinds = events.map(\.kind)
    #expect(kinds == expected, sourceLocation: sourceLocation)
  }

#if canImport(_StringProcessing)
  private var encodedEventMessagesCommonPrefix: [Regex<Substring>] {
    var result = [
      /Test run started\./,
      /Testing Library Version: .*/,
    ]

    if Testing.targetTriple != nil {
      result += [
        /Target Platform: .*/,
      ]
    }
    return result
  }

  private func assertEncodedEventMessages<R>(
    _ test: Test,
    match expected: [Regex<R>],
    sourceLocation: SourceLocation = #Testing::sourceLocation
  ) async {
    let events = await encodedEvents(for: test, encodeMessagesField: true)
    let messages = events.flatMap(\.messages).map(\.text)

    #expect(messages.count == expected.count, sourceLocation: sourceLocation)
    for (actual, expected) in zip(messages, expected) {
      #expect(throws: Never.self, sourceLocation: sourceLocation) {
        try #expect(expected.wholeMatch(in: actual) != nil, sourceLocation: sourceLocation)
      }
    }
}
#endif

  @Test
  func `Non-parameterized test repetitions don't nest`() async throws {
    let test = Test(name: "Test Name") {}
    await assertEncodedEventKinds(test, equals: [
      .runStarted,
      .testStarted,
      .testCaseStarted,
      .testCaseEnded,
      .testCaseStarted,
      .testCaseEnded,
      .testEnded,
      .runEnded
    ])

#if canImport(_StringProcessing)
    await assertEncodedEventMessages(test, match: encodedEventMessagesCommonPrefix + [
      /Test ".*" started\./,
      /Test ".*" started \(repetition 2\)\./,
      /Test ".*" passed after .* seconds\./,
      /Test run .* passed after .* seconds\./,
    ])
#endif
  }

  @Test
  func `Parameterized test repetitions are bookended with testStarted/Ended events`() async throws {
    let test = Test(arguments: [0], name: "Test Name") { _ in }
    await assertEncodedEventKinds(test, equals: [
      .runStarted,
      .testStarted,
      .testCaseStarted,
      .testCaseEnded,
      .testCaseStarted,
      .testCaseEnded,
      .testEnded,
      .runEnded
    ])

#if canImport(_StringProcessing)
    await assertEncodedEventMessages(test, match: encodedEventMessagesCommonPrefix + [
      /Test ".*" started\./,
      /Test case passing .* to ".*" started\./,
      /Test case passing .* to ".*" started \(repetition 2\)\./,
      /Test ".*" with 1 test case passed after .* seconds\./,
      /Test run .* passed after .* seconds\./,
    ])
#endif
  }

  @Test
  func `Non-parameterized test cancellation reports both testCancelled and testCaseCancelled events, stops iterating the whole test`() async throws {
    let test = Test(name: "Test Name") {
      try Test.cancel()
    }

    await assertEncodedEventKinds(test, equals: [
      .runStarted,
      .testStarted,
      .testCaseStarted,
      .testCancelled,
      .testCaseCancelled,
      .testCaseEnded,
      .testEnded,
      .runEnded
    ])

#if canImport(_StringProcessing)
    await assertEncodedEventMessages(test, match: encodedEventMessagesCommonPrefix + [
      /Test ".*" started\./,
      /Test ".*" was cancelled after .* seconds./,
      /Test run .* passed after .* seconds\./,
    ])
#endif
  }

  @Test
  func `Parameterized test cancellation reports a testCaseCancelled event, stops iterating that test case`() async throws {
    let test = Test(arguments: [0], name: "Test Name") { _ in
      try Test.cancel()
    }

    await assertEncodedEventKinds(test, equals: [
      .runStarted,
      .testStarted,
      .testCaseStarted,
      .testCaseCancelled,
      .testCaseEnded,
      .testEnded,
      .runEnded
    ])

#if canImport(_StringProcessing)
    await assertEncodedEventMessages(test, match: encodedEventMessagesCommonPrefix + [
      /Test ".*" started\./,
      /Test case passing .* to ".*" started\./,
      /Test ".*" with 1 test case passed after .* seconds\./,
      /Test run .* passed after .* seconds\./,
    ])
#endif
  }
}

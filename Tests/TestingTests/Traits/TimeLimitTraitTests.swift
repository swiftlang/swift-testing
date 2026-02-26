//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

#if canImport(Foundation)
private import Foundation
#endif
#if canImport(Synchronization)
private import Synchronization
#endif

@Suite("TimeLimitTrait Tests", .tags(.traitRelated))
struct TimeLimitTraitTests {
  @Test(".timeLimit() factory method")
  func timeLimitTrait() throws {
    let test = Test(.timeLimit(.minutes(2))) {}
    #expect(test.timeLimit == .seconds(60) * 2)
  }

  @Test("adjustedTimeLimit(configuration:) function")
  func adjustedTimeLimitMethod() throws {
    let oneHour = Duration.seconds(60 * 60)

    var configuration = Configuration()
    configuration.testTimeLimitGranularity = oneHour

    for minutes in 1 ... 60 {
      let test = Test(.timeLimit(.minutes(minutes))) {}
      let adjustedTimeLimit = test.adjustedTimeLimit(configuration: configuration)
      #expect(adjustedTimeLimit == oneHour)
    }

    for minutes in 61 ... 120 {
      let test = Test(.timeLimit(.minutes(minutes))) {}
      let adjustedTimeLimit = test.adjustedTimeLimit(configuration: configuration)
      #expect(adjustedTimeLimit == oneHour * 2)
    }
  }

  @Test("Configuration.maximumTestTimeLimit property")
  func maximumTimeLimit() throws {
    let tenMinutes = Duration.seconds(60 * 10)
    var configuration = Configuration()
    configuration.maximumTestTimeLimit = tenMinutes
    let test = Test(.timeLimit(.minutes(20))) {}
    let adjustedTimeLimit = test.adjustedTimeLimit(configuration: configuration)
    #expect(adjustedTimeLimit == tenMinutes)
  }

  @Test("Configuration.defaultTestTimeLimit property")
  func defaultTimeLimit() throws {
    var configuration = Configuration()
    configuration.defaultTestTimeLimit = .seconds(99)
    let test = Test {}
    let adjustedTimeLimit = test.adjustedTimeLimit(configuration: configuration)
    #expect(adjustedTimeLimit == .seconds(120))
  }

  @Test("Configuration.defaultTestTimeLimit property set higher than maximum")
  func defaultTimeLimitGreaterThanMaximum() throws {
    var configuration = Configuration()
    configuration.maximumTestTimeLimit = .seconds(130)
    configuration.defaultTestTimeLimit = .seconds(999)
    let test = Test {}
    let adjustedTimeLimit = test.adjustedTimeLimit(configuration: configuration)
    #expect(adjustedTimeLimit == .seconds(130))
  }

  @Test("Test times out when overrunning .timeLimit() trait")
  func testTimesOutDueToTrait() async throws {
    await confirmation("Issue recorded", expectedCount: 10) { issueRecorded in
      var configuration = Configuration()
      configuration.testTimeLimitGranularity = .milliseconds(1)
      configuration.eventHandler = { event, _ in
        guard case let .issueRecorded(issue) = event.kind,
              case .timeLimitExceeded = issue.kind else {
          return
        }
        issueRecorded()
      }

      await Test(.timeLimit(.milliseconds(10)), arguments: 0 ..< 10) { _ in
        try await Test.Clock.sleep(for: .milliseconds(100))
      }.run(configuration: configuration)
    }
  }

  @Test("Test times out when overrunning .timeLimit() trait (inherited)")
  func testTimesOutDueToInheritedTrait() async throws {
    await confirmation("Issue recorded", expectedCount: 10) { issueRecorded in
      var configuration = Configuration()
      configuration.testTimeLimitGranularity = .milliseconds(1)
      configuration.maximumTestTimeLimit = .milliseconds(10)
      configuration.eventHandler = { event, _ in
        guard case let .issueRecorded(issue) = event.kind,
              case .timeLimitExceeded = issue.kind else {
          return
        }
        issueRecorded()
      }

      await runTest(for: TestTypeThatTimesOut.self, configuration: configuration)
    }
  }

  @Test("Test times out when overrunning default time limit")
  func testTimesOutDueToDefaultTimeLimit() async throws {
    await confirmation("Issue recorded", expectedCount: 10) { issueRecorded in
      var configuration = Configuration()
      configuration.testTimeLimitGranularity = .milliseconds(1)
      configuration.defaultTestTimeLimit = .milliseconds(10)
      configuration.eventHandler = { event, _ in
        guard case let .issueRecorded(issue) = event.kind,
              case .timeLimitExceeded = issue.kind else {
          return
        }
        issueRecorded()
      }

      await Test(arguments: 0 ..< 10) { _ in
        try await Test.Clock.sleep(for: .milliseconds(100))
      }.run(configuration: configuration)
    }
  }

  @Test("Test times out when overrunning maximum time limit")
  func testTimesOutDueToMaximumTimeLimit() async throws {
    await confirmation("Issue recorded", expectedCount: 10) { issueRecorded in
      var configuration = Configuration()
      configuration.testTimeLimitGranularity = .milliseconds(1)
      configuration.maximumTestTimeLimit = .milliseconds(10)
      configuration.eventHandler = { event, _ in
        guard case let .issueRecorded(issue) = event.kind,
              case .timeLimitExceeded = issue.kind else {
          return
        }
        issueRecorded()
      }

      await Test(arguments: 0 ..< 10) { _ in
        try await Test.Clock.sleep(for: .milliseconds(100))
      }.run(configuration: configuration)
    }
  }

  @Test("Test does not block until end of time limit")
  func doesNotWaitUntilEndOfTimeLimit() async throws {
    var configuration = Configuration()
    configuration.testTimeLimitGranularity = .milliseconds(1)
    configuration.maximumTestTimeLimit = .seconds(60)

    // Do not use Clock.measure {} here because it will include the time spent
    // waiting for the test's task to be scheduled by the Swift runtime. We
    // only want to measure the time from the start of the test until the call
    // to run(configuration:) returns.
    let timeStarted = Mutex<Test.Clock.Instant?>()
    await Test {
      timeStarted.withLock { timeStarted in
        timeStarted = .now
      }
      try await Test.Clock.sleep(for: .nanoseconds(1))
    }.run(configuration: configuration)
    let timeEnded = Test.Clock.Instant.now

    do {
      let timeStarted = timeStarted.rawValue
      let timeAwaited = try #require(timeStarted).duration(to: timeEnded)
      #expect(timeAwaited < .seconds(5))
    }
  }

  @Test("Cancelled tests can exit early (cancellation checking works)")
  func cancelledTestExitsEarly() async throws {
    let timeAwaited = await Test.Clock().measure {
      await withTaskGroup { taskGroup in
        taskGroup.addTask {
          await Test {
            try await Test.Clock.sleep(for: .seconds(60) * 60)
          }.run()
        }
        taskGroup.cancelAll()
      }
    }

    // Expect that the time awaited is significantly less than the duration of
    // the sleep above. To avoid flakiness in CI, allow for a somewhat long
    // wait, but still much less than the full sleep duration.
    #expect(timeAwaited < .seconds(60))
  }

  @Test("Time limit exceeded event includes its associated Test")
  func timeLimitExceededEventProperties() async throws {
    await confirmation("Issue recorded") { issueRecorded in
      var configuration = Configuration()
      configuration.testTimeLimitGranularity = .milliseconds(1)
      configuration.eventHandler = { event, context in
        guard case let .issueRecorded(issue) = event.kind,
              case .timeLimitExceeded = issue.kind,
              let test = context.test else {
          return
        }
        issueRecorded()
        #expect(test.timeLimit == .milliseconds(10))
        #expect(context.testCase != nil)
      }

      await Test(.timeLimit(.milliseconds(10))) {
        try await Test.Clock.sleep(for: .milliseconds(100))
      }.run(configuration: configuration)
    }
  }

  @Test("TimeoutError.description property")
  func timeoutErrorDescription() async throws {
    let timeLimit = TimeValue((0, 0))
    #expect(String(describing: TimeoutError(timeLimit: timeLimit)).contains("0.000"))
  }

  @Test("Issue.Kind.timeLimitExceeded.description property",
    arguments: [
      (123, 0, "123.000"),
      (123, 000_100_000_000_000_000, "123.000"),
      (0, 000_100_000_000_000_000, "0.001"),
      (0, 000_000_001_000_000_000, "0.001"),
      (0, 000_000_000_000_000_001, "0.001"),
      (123, 456_000_000_000_000_000, "123.456"),
      (123, 1_000_000_000_000_000_000, "124.000"),
    ]
  )
  func timeLimitExceededDescription(seconds: Int64, attoseconds: Int64, description: String) async throws {
    let issueKind = Issue.Kind.timeLimitExceeded(timeLimitComponents: (seconds, attoseconds))
    #expect(String(describing: issueKind) == "Time limit was exceeded: \(description) seconds")
  }
}

// MARK: - Fixtures

@Suite(.hidden, .timeLimit(.minutes(10)))
struct TestTypeThatTimesOut {
  @Test(.hidden, arguments: 0 ..< 10)
  func f(i: Int) async throws {
    try await Test.Clock.sleep(for: .milliseconds(100))
  }
}

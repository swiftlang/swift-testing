//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ExperimentalTestRunning) @_spi(ExperimentalEventHandling) import Testing

@Suite("TimeLimitTrait Tests", .tags(.traitRelated))
struct TimeLimitTraitTests {
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test(".timeLimit() factory method")
  func timeLimitTrait() throws {
    let test = Test(.timeLimit(.seconds(20))) {}
    #expect(test.timeLimit == .seconds(20))
  }

  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test("adjustedTimeLimit(configuration:) function")
  func adjustedTimeLimitMethod() throws {
    for seconds in 1 ... 59 {
      for milliseconds in 0 ... 100 {
        let test = Test(.timeLimit(.seconds(seconds) + .milliseconds(milliseconds * 10))) {}
        let adjustedTimeLimit = test.adjustedTimeLimit(configuration: .init())
        #expect(adjustedTimeLimit == .seconds(60))
      }
    }

    for seconds in 60 ... 119 {
      let test = Test(.timeLimit(.seconds(seconds) + .milliseconds(1))) {}
      let adjustedTimeLimit = test.adjustedTimeLimit(configuration: .init())
      #expect(adjustedTimeLimit == .seconds(120))
    }
  }

  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test("Configuration.maximumTestTimeLimit property")
  func maximumTimeLimit() throws {
    var configuration = Configuration()
    configuration.maximumTestTimeLimit = .seconds(99)
    let test = Test(.timeLimit(.seconds(100) + .milliseconds(100))) {}
    let adjustedTimeLimit = test.adjustedTimeLimit(configuration: configuration)
    #expect(adjustedTimeLimit == .seconds(99))
  }

  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test("Configuration.defaultTestTimeLimit property")
  func defaultTimeLimit() throws {
    var configuration = Configuration()
    configuration.defaultTestTimeLimit = .seconds(99)
    let test = Test {}
    let adjustedTimeLimit = test.adjustedTimeLimit(configuration: configuration)
    #expect(adjustedTimeLimit == .seconds(120))
  }

  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test("Configuration.defaultTestTimeLimit property set higher than maximum")
  func defaultTimeLimitGreaterThanMaximum() throws {
    var configuration = Configuration()
    configuration.maximumTestTimeLimit = .seconds(130)
    configuration.defaultTestTimeLimit = .seconds(999)
    let test = Test {}
    let adjustedTimeLimit = test.adjustedTimeLimit(configuration: configuration)
    #expect(adjustedTimeLimit == .seconds(130))
  }

  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
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

  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
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

  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
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

  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
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

  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test("Test does not block until end of time limit")
  func doesNotWaitUntilEndOfTimeLimit() async throws {
    var configuration = Configuration()
    configuration.testTimeLimitGranularity = .milliseconds(1)
    configuration.maximumTestTimeLimit = .seconds(60)

    // Do not use Clock.measure {} here because it will include the time spent
    // waiting for the test's task to be scheduled by the Swift runtime. We
    // only want to measure the time from the start of the test until the call
    // to run(configuration:) returns.
    let timeStarted = Locked<Test.Clock.Instant?>()
    await Test {
      timeStarted.withLock { timeStarted in
        timeStarted = .now
      }
      try await Test.Clock.sleep(for: .nanoseconds(1))
    }.run(configuration: configuration)
    let timeEnded = Test.Clock.Instant.now

    let timeAwaited = try #require(timeStarted.rawValue).duration(to: timeEnded)
    #expect(timeAwaited < .seconds(1))
  }

  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test("Cancelled tests can exit early (cancellation checking works)")
  func cancelledTestExitsEarly() async throws {
    let timeAwaited = await Test.Clock().measure {
      await withTaskGroup(of: Void.self) { taskGroup in
        taskGroup.addTask {
          await Test {
            try await Test.Clock.sleep(for: .seconds(60))
          }.run()
        }
        taskGroup.cancelAll()
      }
    }
    #expect(timeAwaited < .seconds(5)) // less than the 60 second sleep
  }

  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test("Time limit exceeded event includes its associated Test")
  func timeLimitExceededEventProperties() async throws {
    await confirmation("Issue recorded") { issueRecorded in
      var configuration = Configuration()
      configuration.testTimeLimitGranularity = .milliseconds(1)
      configuration.eventHandler = { event, context in
        guard case let .issueRecorded(issue) = event.kind,
              case .timeLimitExceeded = issue.kind,
              let test = context.test,
              let testCase = context.testCase
        else {
          return
        }
        issueRecorded()
        #expect(test.timeLimit == .milliseconds(10))
        #expect(testCase != nil)
      }

      await Test(.timeLimit(.milliseconds(10))) {
        try await Test.Clock.sleep(for: .milliseconds(100))
      }.run(configuration: configuration)
    }
  }

#if !SWT_NO_XCTEST_SCAFFOLDING && SWT_TARGET_OS_APPLE
  @Test("TimeoutError.description property")
  func timeoutErrorDescription() async throws {
    let timeLimit = TimeValue((0, 0))
    #expect(String(describing: TimeoutError(timeLimit: timeLimit)).contains("0.000"))
  }
#endif

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

func timeLimitIfAvailable(milliseconds: UInt64) -> any SuiteTrait {
  // @available can't be applied to a suite type, so we can't mark the suite as
  // available only on newer OSes.
  if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
    .timeLimit(.milliseconds(milliseconds))
  } else {
    .disabled(".timeLimit() not available")
  }
}

@Suite(.hidden, timeLimitIfAvailable(milliseconds: 10))
struct TestTypeThatTimesOut {
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  @Test(.hidden, arguments: 0 ..< 10)
  func f(i: Int) async throws {
    try await Test.Clock.sleep(for: .milliseconds(100))
  }
}

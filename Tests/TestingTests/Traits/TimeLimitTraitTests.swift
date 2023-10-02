//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ExperimentalTestRunning) @_spi(ExperimentalEventHandling) @_spi(ExperimentalParameterizedTesting) import Testing

@Suite("TimeLimitTrait Tests", .tags("trait"))
struct TimeLimitTraitTests {
  @available(_clockAPI, *)
  @Test(".timeLimit() factory method")
  func timeLimitTrait() throws {
    let test = Test(.timeLimit(.seconds(20))) {}
    #expect(test.timeLimit == .seconds(20))
  }

  @available(_clockAPI, *)
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

  @available(_clockAPI, *)
  @Test("Configuration.maximumTestTimeLimit property")
  func maximumTimeLimit() throws {
    var configuration = Configuration()
    configuration.maximumTestTimeLimit = .seconds(99)
    let test = Test(.timeLimit(.seconds(100) + .milliseconds(100))) {}
    let adjustedTimeLimit = test.adjustedTimeLimit(configuration: configuration)
    #expect(adjustedTimeLimit == .seconds(99))
  }

  @available(_clockAPI, *)
  @Test("Configuration.defaultTestTimeLimit property")
  func defaultTimeLimit() throws {
    var configuration = Configuration()
    configuration.defaultTestTimeLimit = .seconds(99)
    let test = Test {}
    let adjustedTimeLimit = test.adjustedTimeLimit(configuration: configuration)
    #expect(adjustedTimeLimit == .seconds(120))
  }

  @available(_clockAPI, *)
  @Test("Configuration.defaultTestTimeLimit property set higher than maximum")
  func defaultTimeLimitGreaterThanMaximum() throws {
    var configuration = Configuration()
    configuration.maximumTestTimeLimit = .seconds(130)
    configuration.defaultTestTimeLimit = .seconds(999)
    let test = Test {}
    let adjustedTimeLimit = test.adjustedTimeLimit(configuration: configuration)
    #expect(adjustedTimeLimit == .seconds(130))
  }

  @available(_clockAPI, *)
  @Test("Configuration.defaultTestTimeLimit environment variable")
  func defaultTimeLimitEnvironmentVariable() throws {
    let oldEnvironmentVariable = Environment.variable(named: "SWT_DEFAULT_TEST_TIME_LIMIT_NANOSECONDS")
    Environment.setVariable("1234567890", named: "SWT_DEFAULT_TEST_TIME_LIMIT_NANOSECONDS")
    defer {
      Environment.setVariable(oldEnvironmentVariable, named: "SWT_DEFAULT_TEST_TIME_LIMIT_NANOSECONDS")
    }
    let configuration = Configuration()
    #expect(configuration.defaultTestTimeLimit == .nanoseconds(1234567890))
  }

  @available(_clockAPI, *)
  @Test("Configuration.maximumTestTimeLimit environment variable")
  func maximumTimeLimitEnvironmentVariable() throws {
    let oldEnvironmentVariable = Environment.variable(named: "SWT_MAXIMUM_TEST_TIME_LIMIT_NANOSECONDS")
    Environment.setVariable("1234567890", named: "SWT_MAXIMUM_TEST_TIME_LIMIT_NANOSECONDS")
    defer {
      Environment.setVariable(oldEnvironmentVariable, named: "SWT_MAXIMUM_TEST_TIME_LIMIT_NANOSECONDS")
    }
    let configuration = Configuration()
    #expect(configuration.maximumTestTimeLimit == .nanoseconds(1234567890))
  }

  @available(_clockAPI, *)
  @Test("Configuration.testTimeLimitGranularity environment variable")
  func timeLimitGranularityEnvironmentVariable() throws {
    let oldEnvironmentVariable = Environment.variable(named: "SWT_TEST_TIME_LIMIT_GRANULARITY_NANOSECONDS")
    Environment.setVariable("1234567890", named: "SWT_TEST_TIME_LIMIT_GRANULARITY_NANOSECONDS")
    defer {
      Environment.setVariable(oldEnvironmentVariable, named: "SWT_TEST_TIME_LIMIT_GRANULARITY_NANOSECONDS")
    }
    let configuration = Configuration()
    #expect(configuration.testTimeLimitGranularity == .nanoseconds(1234567890))
  }

  @available(_clockAPI, *)
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

  @available(_clockAPI, *)
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

  @available(_clockAPI, *)
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

  @available(_clockAPI, *)
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

  @available(_clockAPI, *)
  @Test("Test does not block until end of time limit")
  func doesNotWaitUntilEndOfTimeLimit() async throws {
    let timeAwaited = await Test.Clock().measure {
      var configuration = Configuration()
      configuration.testTimeLimitGranularity = .milliseconds(1)
      configuration.maximumTestTimeLimit = .seconds(60)

      await Test {
        try await Test.Clock.sleep(for: .nanoseconds(1))
      }.run(configuration: configuration)
    }
    #expect(timeAwaited < .seconds(1))
  }

  @available(_clockAPI, *)
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
    #expect(timeAwaited < .seconds(1))
  }

  @available(_clockAPI, *)
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
    #expect(String(describing: TimeoutError(timeLimitComponents: (0, 0))).contains("0.000"))
  }
#endif

  @Test("Issue.Kind.timeLimitExceeded.description property",
    arguments: [
      (123, 0, "123.000"),
      (123, 000_100_000_000_000_000, "123.000"),
      (0, 000_100_000_000_000_000, "0.001"),
      (0, 000_000_001_000_000_000, "0.001"),
      (0, 000_000_000_000_000_001, "0.000"),
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
  if #available(_clockAPI, *) {
    .timeLimit(.milliseconds(milliseconds))
  } else {
    .disabled(".timeLimit() not available")
  }
}

@Suite(.hidden, timeLimitIfAvailable(milliseconds: 10))
struct TestTypeThatTimesOut {
  @available(_clockAPI, *)
  @Test(.hidden, arguments: 0 ..< 10)
  func f(i: Int) async throws {
    try await Test.Clock.sleep(for: .milliseconds(100))
  }
}

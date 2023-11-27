//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type that runs tests according to a given configuration.
@_spi(ExperimentalTestRunning)
public struct Runner: Sendable {
  /// The plan to follow when running the associated tests.
  public var plan: Plan

  /// The set of tests this runner will run.
  public var tests: [Test] { plan.steps.map(\.test) }

  /// The runner's configuration.
  public var configuration: Configuration

  /// Initialize an instance of this type that runs the specified series of
  /// tests.
  ///
  /// - Parameters:
  ///   - tests: The tests to run.
  ///   - configuration: The configuration to use for running.
  public init(testing tests: [Test], configuration: Configuration = .init()) async {
    self.plan = await Plan(tests: tests, configuration: configuration)
    self.configuration = configuration
  }

  /// Initialize an instance of this type that runs the tests in the specified
  /// plan.
  ///
  /// - Parameters:
  ///   - plan: A previously constructed plan.
  ///   - configuration: The configuration to use for running.
  public init(plan: Plan, configuration: Configuration = .init()) {
    self.plan = plan
    self.configuration = configuration
  }

  /// Initialize an instance of this type that runs all tests found in the
  /// current process.
  ///
  /// - Parameters:
  ///   - configuration: The configuration to use for running.
  public init(configuration: Configuration = .init()) async {
    let plan = await Plan(configuration: configuration)
    self.init(plan: plan, configuration: configuration)
  }
}

// MARK: - Running tests

@_spi(ExperimentalTestRunning)
extension Runner {
  /// Catch errors thrown from a closure and process them as issues instead of
  /// allowing them to propagate to the caller.
  ///
  /// - Parameters:
  ///   - step: The runner plan step that is being run.
  ///   - sourceLocation: The source location to attribute caught errors to. If
  ///     `nil`, the source location of `step.test` is used.
  ///   - body: A closure that might throw an error.
  ///
  /// This function encapsulates the standard error handling performed by
  /// ``Runner`` when running a test or test case.
  ///
  /// If an error occurs and the test configuration specifies terminating on
  /// failure, then the current task is cancelled. Tests should therefore
  /// periodically check `Task.isCancelled` or call `Task.checkCancellation()`
  /// to determine if they should exit early.
  private func _withErrorHandling(for step: Plan.Step, sourceLocation: SourceLocation, _ body: () async throws -> Void) async throws -> Void {
    // Ensure that we are capturing backtraces for errors before we start
    // expecting to see them.
    Backtrace.startCachingForThrownErrors()
    defer {
      Backtrace.flushThrownErrorCache()
    }

    // A local error type that represents an error that was already handled in
    // a previous scope.
    //
    // Instances of this type are thrown from this function after any other
    // error is caught. Subsequent outer calls to this function will then
    // avoid producing events for the same error. We bother doing this at all
    // because we may need to cancel the parent task after a child task is
    // cancelled, and the simplest way to do so is to just keep rethrowing.
    struct AlreadyHandled: Error {}

    do {
      try await body()

    } catch is AlreadyHandled {
      // This error stands in for an earlier error that should not be reported
      // again. It is not converted to an event.

    } catch is ExpectationFailedError {
      // This error is thrown by `__check()` to indicate that its condition
      // evaluated to `false`. That function emits its own issue, so we don't
      // need to emit one here.

    } catch {
      Issue.record(
        .errorCaught(error),
        comments: [],
        backtrace: Backtrace(forFirstThrowOf: error),
        sourceLocation: sourceLocation,
        configuration: configuration
      )
    }
  }

  /// Run this test.
  ///
  /// - Parameters:
  ///   - step: The runner plan step to run.
  ///   - depth: How deep into the step graph this call is. The first call has a
  ///     depth of `0`.
  ///
  /// - Throws: Whatever is thrown from the test body. Thrown errors are
  ///   normally reported as test failures.
  ///
  /// This function sets ``Test/current``, then runs the test's content.
  ///
  /// The caller is responsible for configuring a task group for the test to run
  /// in if it should be parallelized. If `step.test` is parameterized and
  /// parallelization is supported and enabled, its test cases will be run in a
  /// nested task group.
  ///
  /// ## See Also
  ///
  /// - ``Runner/run()``
  private func _runStep(atRootOf stepGraph: Graph<String, Plan.Step?>, depth: Int) async throws {
    // Exit early if the task has already been cancelled.
    try Task.checkCancellation()

    // Whether to send a `.testEnded` event at the end of running this step.
    // Some steps' actions may not require a final event to be sent — for
    // example, a skip event only sends `.testSkipped`.
    let shouldSendTestEnded: Bool

    // Determine what action to take for this step.
    if let step = stepGraph.value {
      Event.post(.planStepStarted(step), for: step.test, configuration: configuration)

      // Determine what kind of event to send for this step based on its action.
      switch step.action {
      case .run:
        Event.post(.testStarted, for: step.test, configuration: configuration)
        shouldSendTestEnded = true
      case let .skip(skipInfo):
        Event.post(.testSkipped(skipInfo), for: step.test, configuration: configuration)
        shouldSendTestEnded = false
      case let .recordIssue(issue):
        Event.post(.issueRecorded(issue), for: step.test, configuration: configuration)
        shouldSendTestEnded = false
      }
    } else {
      shouldSendTestEnded = false
    }
    defer {
      if let step = stepGraph.value {
        if shouldSendTestEnded {
          Event.post(.testEnded, for: step.test, configuration: configuration)
        }
        Event.post(.planStepEnded(step), for: step.test, configuration: configuration)
      }
    }

    if let step = stepGraph.value, case .run = step.action, let testCases = await step.test.testCases {
      try await Test.withCurrent(step.test) {
        try await _withErrorHandling(for: step, sourceLocation: step.test.sourceLocation) {
          try await _runTestCases(testCases, within: step)
        }
      }
    }

    let childGraphs = stepGraph.children.sorted { $0.key < $1.key }
    try await withThrowingTaskGroup(of: Void.self) { taskGroup in
      if configuration.isParallelizationEnabled {
        for (_, childGraph) in childGraphs {
          _ = taskGroup.addTaskUnlessCancelled {
            try await _runStep(atRootOf: childGraph, depth: depth + 1)
          }
        }
        try await taskGroup.waitForAll()
      } else {
        _ = taskGroup.addTaskUnlessCancelled {
          for (_, childGraph) in childGraphs {
            try await _runStep(atRootOf: childGraph, depth: depth + 1)
          }
        }
        try await taskGroup.waitForAll()
      }
    }
  }

  /// Run a sequence of test cases.
  ///
  /// - Parameters:
  ///   - testCases: The test cases to be run.
  ///   - step: The runner plan step associated with this test case.
  ///
  /// - Throws: Whatever is thrown from a test case's body. Thrown errors are
  ///   normally reported as test failures.
  ///
  /// If parallelization is supported and enabled, the generated test cases will
  /// be run in parallel using a task group.
  private func _runTestCases(_ testCases: some Sequence<Test.Case>, within step: Plan.Step) async throws {
    if configuration.isParallelizationEnabled {
      try await withThrowingTaskGroup(of: Void.self) { taskGroup in
        for testCase in testCases {
          _ = taskGroup.addTaskUnlessCancelled {
            try await _runTestCase(testCase, within: step)
          }
        }
        try await taskGroup.waitForAll()
      }
    } else {
      for testCase in testCases {
        try Task.checkCancellation()
        try await _runTestCase(testCase, within: step)
      }
    }
  }

  /// Run a test case.
  ///
  /// - Parameters:
  ///   - testCase: The test case to run.
  ///   - step: The runner plan step associated with this test case.
  ///
  /// - Throws: Whatever is thrown from the test case's body. Thrown errors
  ///   are normally reported as test failures.
  ///
  /// This function sets ``Test/Case/current``, then invokes the test case's
  /// body closure.
  private func _runTestCase(_ testCase: Test.Case, within step: Plan.Step) async throws {
    // Exit early if the task has already been cancelled.
    try Task.checkCancellation()

    Event.post(.testCaseStarted, for: step.test, testCase: testCase, configuration: configuration)
    defer {
      Event.post(.testCaseEnded, for: step.test, testCase: testCase, configuration: configuration)
    }

    try await Test.Case.withCurrent(testCase) {
      let sourceLocation = step.test.sourceLocation
      try await _withErrorHandling(for: step, sourceLocation: sourceLocation) {
        try await withTimeLimit(for: step.test, configuration: configuration) {
          try await testCase.body()
        } timeoutHandler: { timeLimit in
          Issue.record(
            .timeLimitExceeded(timeLimitComponents: timeLimit),
            comments: [],
            backtrace: .current(),
            sourceLocation: sourceLocation,
            configuration: configuration
          )
        }
      }
    }
  }

  /// Run the tests in this runner's plan.
  public func run() async {
    await Self._run(self)
  }

  /// Run the tests in a runner's plan with a given configuration.
  ///
  /// - Parameters:
  ///   - runner: The runner to run.
  ///   - configuration: The configuration to use for running. The value of this
  ///     argument temporarily replaces the value of `runner`'s
  ///     ``Runner/configuration`` property.
  ///
  /// This function is `static` so that it cannot accidentally reference `self`
  /// or `self.configuration` when it should use a modified copy of either.
  private static func _run(_ runner: Self) async {
    var runner = runner
    runner.configureEventHandlerRuntimeState()

    await Configuration.withCurrent(runner.configuration) {
      Event.post(.runStarted, for: nil, testCase: nil, configuration: runner.configuration)
      defer {
        Event.post(.runEnded, for: nil, testCase: nil, configuration: runner.configuration)
      }

      await withTaskGroup(of: Void.self) { [runner] taskGroup in
        _ = taskGroup.addTaskUnlessCancelled {
          try? await runner._runStep(atRootOf: runner.plan.stepGraph, depth: 0)
        }
        await taskGroup.waitForAll()
      }
    }
  }
}

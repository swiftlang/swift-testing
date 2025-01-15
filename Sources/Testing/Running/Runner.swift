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
@_spi(ForToolsIntegrationOnly)
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
    let plan = await Plan(tests: tests, configuration: configuration)
    self.init(plan: plan, configuration: configuration)
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

extension Runner {
  /// The current configuration _while_ running.
  ///
  /// This should be used from the functions in this extension which access the
  /// current configuration. This is important since individual tests or suites
  /// may have traits which customize the execution scope of their children,
  /// including potentially modifying the current configuration.
  private static var _configuration: Configuration {
    .current ?? .init()
  }

  /// Apply the custom scope for any test scope providers of the traits
  /// associated with a specified test by calling their
  /// ``TestScoping/provideScope(for:testCase:performing:)`` function.
  ///
  /// - Parameters:
  ///   - test: The test being run, for which to provide custom scope.
  ///   - testCase: The test case, if applicable, for which to provide custom
  ///     scope.
  ///   - body: A function to execute from within the
  ///     ``TestScoping/provideScope(for:testCase:performing:)`` function of
  ///     each non-`nil` scope provider of the traits applied to `test`.
  ///
  /// - Throws: Whatever is thrown by `body` or by any of the
  ///   ``TestScoping/provideScope(for:testCase:performing:)`` function calls.
  private static func _applyScopingTraits(
    for test: Test,
    testCase: Test.Case?,
    _ body: @escaping @Sendable () async throws -> Void
  ) async throws {
    // If the test does not have any traits, exit early to avoid unnecessary
    // heap allocations below.
    if test.traits.isEmpty {
      return try await body()
    }

    // Construct a recursive function that invokes each trait's ``execute(_:for:testCase:)``
    // function. The order of the sequence is reversed so that the last trait is
    // the one that invokes body, then the second-to-last invokes the last, etc.
    // and ultimately the first trait is the first one to be invoked.
    let executeAllTraits = test.traits.lazy
      .reversed()
      .compactMap { $0.scopeProvider(for: test, testCase: testCase) }
      .map { $0.provideScope(for:testCase:performing:) }
      .reduce(body) { executeAllTraits, provideScope in
        {
          try await provideScope(test, testCase, executeAllTraits)
        }
      }

    try await executeAllTraits()
  }

  /// Enumerate the elements of a sequence, parallelizing enumeration in a task
  /// group if a given plan step has parallelization enabled.
  ///
  /// - Parameters:
  ///   - sequence: The sequence to enumerate.
  ///   - stage: The stage at which the runner is operating.
  ///   - body: The function to invoke.
  ///
  /// - Throws: Whatever is thrown by `body`.
  private static func _forEach<E>(
    in sequence: some Sequence<E>,
    stage: Plan.Stage,
    _ body: @Sendable @escaping (E) async throws -> Void
  ) async throws where E: Sendable {
    try await withThrowingTaskGroup(of: Void.self) { taskGroup in
      for element in sequence {
        // Each element gets its own subtask to run in.
        _ = taskGroup.addTaskUnlessCancelled {
          try await body(element)
        }

        // If not parallelizing, wait after each task.
        if stage == .globallySerialized || !_configuration.isParallelizationEnabled {
          try await taskGroup.waitForAll()
        }
      }
    }
  }

  /// Run this test.
  ///
  /// - Parameters:
  ///   - stepGraph: The subgraph whose root value, a step, is to be run.
  ///   - stage: The stage at which the runner is operating.
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
  private static func _runStep(atRootOf stepGraph: Graph<String, Plan.Step?>, stage: Plan.Stage) async throws {
    // Exit early if the task has already been cancelled.
    try Task.checkCancellation()

    let configuration = _configuration

    // Determine what action to take for this step.
    if let step = stepGraph.value, step.starts(in: stage) {
      Event.post(.planStepStarted(step), for: (step.test, nil), configuration: configuration)

      // Determine what kind of event to send for this step based on its action.
      switch step.action {
      case .run:
        Event.post(.testStarted, for: (step.test, nil), configuration: configuration)
      case let .skip(skipInfo):
        Event.post(.testSkipped(skipInfo), for: (step.test, nil), configuration: configuration)
      case let .recordIssue(issue):
        Event.post(.issueRecorded(issue), for: (step.test, nil), configuration: configuration)
      }
    }
    defer {
      if let step = stepGraph.value, step.ends(in: stage) {
        if case .run = step.action {
          Event.post(.testEnded, for: (step.test, nil), configuration: configuration)
        }
        Event.post(.planStepEnded(step), for: (step.test, nil), configuration: configuration)
      }
    }

    if let step = stepGraph.value, case .run = step.action, step.stage == stage {
      await Test.withCurrent(step.test) {
        _ = await Issue.withErrorRecording(at: step.test.sourceLocation, configuration: configuration) {
          try await _applyScopingTraits(for: step.test, testCase: nil) {
            // Run the test function at this step (if one is present.)
            if let testCases = step.test.testCases {
              try await _runTestCases(testCases, within: step, stage: stage)
            }

            // Run the children of this test (i.e. the tests in this suite.)
            try await _runChildren(of: stepGraph, stage: stage)
          }
        }
      }
    } else {
      // There is no test at this node in the graph, so just skip down to the
      // child nodes.
      try await _runChildren(of: stepGraph, stage: stage)
    }
  }

  /// Get the source location corresponding to the root of a plan step graph.
  ///
  /// - Parameters:
  ///   - stepGraph: The plan step graph whose root node is of interest.
  ///
  /// - Returns: The source location of the root node of `stepGraph`, or of the
  ///   first descendant node thereof (sorted by source location.)
  private static func _sourceLocation(of stepGraph: Graph<String, Plan.Step?>) -> SourceLocation? {
    if let result = stepGraph.value?.test.sourceLocation {
      return result
    }
    return stepGraph.children.lazy
      .compactMap { _sourceLocation(of: $0.value) }
      .min()
  }

  /// Recursively run the tests that are children of a given plan step.
  ///
  /// - Parameters:
  ///   - stepGraph: The subgraph whose root value, a step, will be used to
  ///     find children to run.
  ///   - stage: The stage at which the runner is operating.
  ///
  /// - Throws: Whatever is thrown from the test body. Thrown errors are
  ///   normally reported as test failures.
  private static func _runChildren(of stepGraph: Graph<String, Plan.Step?>, stage: Plan.Stage) async throws {
    let childGraphs = if _configuration.isParallelizationEnabled {
      // Explicitly shuffle the steps to help detect accidental dependencies
      // between tests due to their ordering.
      Array(stepGraph.children)
    } else {
      // Sort the children by source order. If a child node is empty but has
      // descendants, the lowest-ordered child node is used. If a child node is
      // empty and has no descendant nodes with source location information,
      // then we sort it before nodes with source location information (though
      // it won't end up doing anything in the test run.)
      //
      // FIXME: this operation is likely O(n log n) or worse when amortized
      // across the entire test plan; Graph should adopt OrderedDictionary if
      // possible so it can pre-sort its nodes once.
      stepGraph.children.sorted { lhs, rhs in
        switch (_sourceLocation(of: lhs.value), _sourceLocation(of: rhs.value)) {
        case let (.some(lhs), .some(rhs)):
          lhs < rhs
        case (.some, _):
          false // x < nil == false
        case (_, .some):
          true // nil < x == true
        default:
          false // stable ordering
        }
      }
    }

    // Run the child nodes.
    try await _forEach(in: childGraphs, stage: stage) { _, childGraph in
      try await _runStep(atRootOf: childGraph, stage: stage)
    }
  }

  /// Run a sequence of test cases.
  ///
  /// - Parameters:
  ///   - testCases: The test cases to be run.
  ///   - step: The runner plan step associated with this test case.
  ///   - stage: The stage at which the runner is operating.
  ///
  /// - Throws: Whatever is thrown from a test case's body. Thrown errors are
  ///   normally reported as test failures.
  ///
  /// If parallelization is supported and enabled, the generated test cases will
  /// be run in parallel using a task group.
  private static func _runTestCases(_ testCases: some Sequence<Test.Case>, within step: Plan.Step, stage: Plan.Stage) async throws {
    // Apply the configuration's test case filter.
    let testCaseFilter = _configuration.testCaseFilter
    let testCases = testCases.lazy.filter { testCase in
      testCaseFilter(testCase, step.test)
    }

    try await _forEach(in: testCases, stage: stage) { testCase in
      try await _runTestCase(testCase, within: step)
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
  private static func _runTestCase(_ testCase: Test.Case, within step: Plan.Step) async throws {
    // Exit early if the task has already been cancelled.
    try Task.checkCancellation()

    let configuration = _configuration

    Event.post(.testCaseStarted, for: (step.test, testCase), configuration: configuration)
    defer {
      Event.post(.testCaseEnded, for: (step.test, testCase), configuration: configuration)
    }

    await Test.Case.withCurrent(testCase) {
      let sourceLocation = step.test.sourceLocation
      await Issue.withErrorRecording(at: sourceLocation, configuration: configuration) {
        try await withTimeLimit(for: step.test, configuration: configuration) {
          try await _applyScopingTraits(for: step.test, testCase: testCase) {
            try await testCase.body()
          }
        } timeoutHandler: { timeLimit in
          let issue = Issue(
            kind: .timeLimitExceeded(timeLimitComponents: timeLimit),
            comments: [],
            sourceContext: .init(backtrace: .current(), sourceLocation: sourceLocation)
          )
          issue.record(configuration: configuration)
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
  ///
  /// This function is `static` so that it cannot accidentally reference `self`
  /// or `self.configuration` when it should use a modified copy of either.
  private static func _run(_ runner: Self) async {
    var runner = runner
    runner.configureEventHandlerRuntimeState()

    // Track whether or not any issues were recorded across the entire run.
    let issueRecorded = Locked(rawValue: false)
    runner.configuration.eventHandler = { [eventHandler = runner.configuration.eventHandler] event, context in
      if case let .issueRecorded(issue) = event.kind, !issue.isKnown {
        issueRecorded.withLock { issueRecorded in
          issueRecorded = true
        }
      }
      eventHandler(event, context)
    }

    await Configuration.withCurrent(runner.configuration) {
      // Post an event for every test in the test plan being run. These events
      // are turned into JSON objects if JSON output is enabled.
      for test in runner.plan.steps.lazy.map(\.test) {
        Event.post(.testDiscovered, for: (test, nil), configuration: runner.configuration)
      }

      Event.post(.runStarted, for: (nil, nil), configuration: runner.configuration)
      defer {
        Event.post(.runEnded, for: (nil, nil), configuration: runner.configuration)
      }

      let repetitionPolicy = runner.configuration.repetitionPolicy
      for iterationIndex in 0 ..< repetitionPolicy.maximumIterationCount {
        Event.post(.iterationStarted(iterationIndex), for: (nil, nil), configuration: runner.configuration)
        defer {
          Event.post(.iterationEnded(iterationIndex), for: (nil, nil), configuration: runner.configuration)
        }

        await withTaskGroup(of: Void.self) { [runner] taskGroup in
          _ = taskGroup.addTaskUnlessCancelled {
            for stage in Plan.Stage.allCases {
              try? await _runStep(atRootOf: runner.plan.stepGraph, stage: stage)
            }
          }
          await taskGroup.waitForAll()
        }

        // Determine if the test plan should iterate again. (The iteration count
        // is handled by the outer for-loop.)
        let shouldContinue = switch repetitionPolicy.continuationCondition {
        case nil:
          true
        case .untilIssueRecorded:
          !issueRecorded.rawValue
        case .whileIssueRecorded:
          issueRecorded.rawValue
        }
        guard shouldContinue else {
          break
        }

        // Reset the run-wide "issue was recorded" flag for this iteration.
        issueRecorded.withLock { issueRecorded in
          issueRecorded = false
        }
      }
    }
  }
}

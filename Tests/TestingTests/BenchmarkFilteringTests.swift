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

@Suite("Benchmark filtering")
struct BenchmarkFilteringTests {
  /// Build a plan for a suite type, marking the named tests as benchmarks.
  private func plan(
    for containingType: Any.Type,
    markingAsBenchmarks benchmarkNames: Set<String>
  ) async -> Runner.Plan {
    var configuration = Configuration()
    configuration.setTestFilter(toInclude: [Test.ID(type: containingType)], includeHiddenTests: true)
    var plan = await Runner.Plan(selecting: containingType, configuration: configuration)
    plan.stepGraph = plan.stepGraph.mapValues { _, step in
      var step = step
      if let name = step?.test.name, benchmarkNames.contains(name) {
        step?.test.isBenchmark = true
      }
      return step
    }
    return plan
  }

  /// The names of the tests in a step graph.
  private func names(in stepGraph: Graph<String, Runner.Plan.Step?>?) -> Set<String> {
    guard let stepGraph else {
      return []
    }
    return Set(stepGraph.compactMap { $0.value?.test.name })
  }

  @Test func `A plan with no benchmarks has nothing to run as benchmarks`() async {
    let plan = await plan(for: MixedSuite.self, markingAsBenchmarks: [])
    #expect(Runner._filter(plan.stepGraph, for: .benchmarks) == nil)
    #expect(names(in: Runner._filter(plan.stepGraph, for: .tests)).isSuperset(of: ["someTest()", "someBenchmark()"]))
  }

  @Test func `Benchmarks are excluded from a test run`() async {
    let plan = await plan(for: MixedSuite.self, markingAsBenchmarks: ["someBenchmark()"])
    let testNames = names(in: Runner._filter(plan.stepGraph, for: .tests))
    #expect(testNames.contains("someTest()"))
    #expect(!testNames.contains("someBenchmark()"))
  }

  @Test func `Tests are excluded from a benchmark run`() async {
    let plan = await plan(for: MixedSuite.self, markingAsBenchmarks: ["someBenchmark()"])
    let benchmarkNames = names(in: Runner._filter(plan.stepGraph, for: .benchmarks))
    #expect(benchmarkNames.contains("someBenchmark()"))
    #expect(!benchmarkNames.contains("someTest()"))
  }

  @Test func `The enclosing suite is kept for either kind of run`() async {
    let plan = await plan(for: MixedSuite.self, markingAsBenchmarks: ["someBenchmark()"])
    #expect(names(in: Runner._filter(plan.stepGraph, for: .tests)).contains("MixedSuite"))
    #expect(names(in: Runner._filter(plan.stepGraph, for: .benchmarks)).contains("MixedSuite"))
  }

  @Test func `A suite containing only benchmarks is kept for a test run`() async {
    let plan = await plan(for: BenchmarksOnlySuite.self, markingAsBenchmarks: ["onlyBenchmark()"])
    // The suite still runs so that its events are unchanged by benchmarks existing.
    let testNames = names(in: Runner._filter(plan.stepGraph, for: .tests))
    #expect(testNames.contains("BenchmarksOnlySuite"))
    #expect(!testNames.contains("onlyBenchmark()"))
    #expect(names(in: Runner._filter(plan.stepGraph, for: .benchmarks)).contains("onlyBenchmark()"))
  }
}

@Suite("Benchmark time budget")
struct BenchmarkTimeBudgetTests {
  @Test func `No time limit leaves the budget to the host`() async {
    let plan = await Runner.Plan(selecting: NoLimitSuite.self, configuration: .init())
    let test = try! #require(plan.steps.first { !$0.test.isSuite }?.test)
    let configuration = Benchmark.Configuration(for: test, testCase: nil, displayName: "x")
    #expect(configuration.timeBudgetNanoseconds == nil)
  }

  @Test func `A time limit becomes the budget`() async {
    let plan = await Runner.Plan(selecting: LimitedSuite.self, configuration: .init())
    let test = try! #require(plan.steps.first { !$0.test.isSuite }?.test)
    let configuration = Benchmark.Configuration(for: test, testCase: nil, displayName: "x")
    // The trait's granularity is one minute.
    #expect(configuration.timeBudgetNanoseconds == 60_000_000_000)
  }

  @Test func `A default time limit becomes the budget`() async {
    var runConfiguration = Configuration()
    runConfiguration.defaultTestTimeLimit = .seconds(120)
    let plan = await Runner.Plan(selecting: NoLimitSuite.self, configuration: runConfiguration)
    let test = try! #require(plan.steps.first { !$0.test.isSuite }?.test)
    let configuration = Configuration.withCurrent(runConfiguration) {
      Benchmark.Configuration(for: test, testCase: nil, displayName: "x")
    }
    #expect(configuration.timeBudgetNanoseconds == 120_000_000_000)
  }

  @Test func `A benchmark budget is not rounded up to the time limit granularity`() async {
    var runConfiguration = Configuration()
    runConfiguration.defaultTestTimeLimit = .seconds(2)
    let plan = await Runner.Plan(selecting: NoLimitSuite.self, configuration: runConfiguration)
    var test = try! #require(plan.steps.first { !$0.test.isSuite }?.test)

    // A test's time limit is still rounded up to one minute.
    #expect(test.adjustedTimeLimit(configuration: runConfiguration) == .seconds(60))

    // A benchmark's is not, since the limit is also its measurement budget.
    test.isBenchmark = true
    #expect(test.adjustedTimeLimit(configuration: runConfiguration) == .seconds(2))

    let configuration = Configuration.withCurrent(runConfiguration) {
      Benchmark.Configuration(for: test, testCase: nil, displayName: "x")
    }
    #expect(configuration.timeBudgetNanoseconds == 2_000_000_000)
  }
}

@Suite(.hidden) struct NoLimitSuite {
  @Test(.hidden) func plain() {}
}

@Suite(.hidden) struct LimitedSuite {
  @Test(.hidden, .timeLimit(.minutes(1))) func limited() {}
}

@Suite("Benchmark time limits")
struct BenchmarkTimeLimitTests {
  @Test func `A benchmark that exceeds its time limit is not a failure`() async throws {
    let plan = await Runner.Plan(
      selecting: SlowBenchmarkSuite.self,
      configuration: {
        var configuration = Configuration()
        configuration.setTestFilter(toInclude: [Test.ID(type: SlowBenchmarkSuite.self)], includeHiddenTests: true)
        return configuration
      }()
    )

    let issues = Mutex<[Issue]>()
    var configuration = Configuration()
    configuration.setTestFilter(toInclude: [Test.ID(type: SlowBenchmarkSuite.self)], includeHiddenTests: true)
    // A budget far shorter than a single iteration.
    configuration.defaultTestTimeLimit = .milliseconds(1)
    configuration.eventHandler = { event, _ in
      if case let .issueRecorded(issue) = event.kind {
        issues.withLock { $0.append(issue) }
      }
    }

    let runner = Runner(plan: plan, configuration: configuration)
    await runner.run()

    let recorded = issues.rawValue
    #expect(!recorded.contains { if case .timeLimitExceeded = $0.kind { true } else { false } })
    #expect(recorded.isEmpty)
  }
}

@Suite(.hidden) struct SlowBenchmarkSuite {
  @Benchmark(.hidden, .timeLimit(seconds: 1)) func slow() {
    let deadline = Test.Clock().now.advanced(by: .milliseconds(200))
    while Test.Clock().now < deadline {}
  }
}

@Suite("Benchmark run kind")
struct BenchmarkRunKindTests {
  @Test func `The benchmark argument selects a benchmark run`() throws {
    let arguments = try parseCommandLineArguments(from: ["PATH", "--benchmark"])
    #expect(arguments.benchmark == true)
    #expect(try configurationForEntryPoint(from: arguments).runKind == .benchmarks)
  }

  @Test func `Omitting the benchmark argument selects a test run`() throws {
    let arguments = try parseCommandLineArguments(from: ["PATH"])
    #expect(arguments.benchmark == nil)
    #expect(try configurationForEntryPoint(from: arguments).runKind == .tests)
  }

  @Test func `A benchmark run measures benchmarks and skips tests`() async throws {
    let events = Mutex<[(testName: String, isBenchmarkResult: Bool)]>([])
    var configuration = Configuration()
    configuration.runKind = .benchmarks
    configuration.setTestFilter(toInclude: [Test.ID(type: MixedRunKindSuite.self)], includeHiddenTests: true)
    configuration.eventHandler = { event, context in
      guard let test = context.test else {
        return
      }
      switch event.kind {
      case .testStarted:
        events.withLock { $0.append((test.name, false)) }
      case .benchmarkResultsReported:
        events.withLock { $0.append((test.name, true)) }
      default:
        break
      }
    }

    let plan = await Runner.Plan(selecting: MixedRunKindSuite.self, configuration: configuration)
    await Runner(plan: plan, configuration: configuration).run()

    let recorded = events.rawValue
    #expect(recorded.contains { $0.testName == "measured()" && $0.isBenchmarkResult })
    #expect(!recorded.contains { $0.testName == "notMeasured()" })
  }

  @Test func `A test run skips benchmarks`() async throws {
    let names = Mutex<[String]>([])
    var configuration = Configuration()
    configuration.runKind = .tests
    configuration.setTestFilter(toInclude: [Test.ID(type: MixedRunKindSuite.self)], includeHiddenTests: true)
    configuration.eventHandler = { event, context in
      if case .testStarted = event.kind, let test = context.test, !test.isSuite {
        names.withLock { $0.append(test.name) }
      }
    }

    let plan = await Runner.Plan(selecting: MixedRunKindSuite.self, configuration: configuration)
    await Runner(plan: plan, configuration: configuration).run()

    #expect(names.rawValue.contains("notMeasured()"))
    #expect(!names.rawValue.contains("measured()"))
  }
}

@Suite(.hidden) struct MixedRunKindSuite {
  @Test(.hidden) func notMeasured() {}

  @Benchmark(.hidden, .timeLimit(seconds: 1)) func measured() {
    var total = 0
    for i in 0..<128 { total &+= i }
    _ = total
  }
}

@Suite(.hidden) struct MixedSuite {
  @Test(.hidden) func someTest() {}
  @Test(.hidden) func someBenchmark() {}
}

@Suite(.hidden) struct BenchmarksOnlySuite {
  @Test(.hidden) func onlyBenchmark() {}
}

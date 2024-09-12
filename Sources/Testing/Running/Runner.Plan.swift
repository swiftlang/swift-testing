//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Runner {
  /// A type describing a runner plan.
  public struct Plan: Sendable {
    /// The action to perform for a test in this plan.
    public enum Action: Sendable {
      /// A type describing options to apply to actions of case
      /// ``Runner/Plan/Action/run(options:)`` when they are run.
      public struct RunOptions: Sendable, Codable {
        /// Whether or not this step should be run in parallel with other tests.
        ///
        /// By default, all steps in a runner plan are run in parallel if the
        /// ``Configuration/isParallelizationEnabled`` property of the
        /// configuration passed during initialization has a value of `true`.
        ///
        /// Traits such as ``Trait/serialized`` applied to individual tests may
        /// affect whether or not that test is parallelized.
        ///
        /// ## See Also
        ///
        /// - ``ParallelizationTrait``
        public var isParallelizationEnabled: Bool
      }

      /// The test should be run.
      ///
      /// - Parameters:
      ///   - options: Options to apply to this action when it is run.
      case run(options: RunOptions)

      /// The test should be skipped.
      ///
      /// - Parameters:
      ///   - skipInfo: A ``SkipInfo`` representing the details of this skip.
      indirect case skip(_ skipInfo: SkipInfo = .init())

      /// The test should record an issue due to a failure during
      /// planning.
      ///
      /// - Parameters:
      ///   - issue: An issue representing the failure encountered during
      ///     planning.
      indirect case recordIssue(_ issue: Issue)

      /// Whether this action should be applied recursively to child tests or
      /// should only be applied to the test it is already associated with.
      var isRecursive: Bool {
        switch self {
        case .run:
          return false
        default:
          // Currently, all possible runner plan actions other than .run are
          // recursively applied. If a new action is added that should not be
          // recursively applied, be sure to update this function with the new
          // case.
          return true
        }
      }

      /// Whether or not this action enables parallelization.
      ///
      /// If this action is of case ``run(options:)``, the value of this
      /// property equals the value of its associated
      /// ``RunOptions/isParallelizationEnabled`` property. Otherwise, the value
      /// of this property is `nil`.
      var isParallelizationEnabled: Bool? {
        if case let .run(options) = self {
          return options.isParallelizationEnabled
        }
        return nil
      }
    }

    /// A type describing a step in a runner plan.
    ///
    /// An instance of this type contains a test and the corresponding action an
    /// instance of ``Runner`` should perform for that test.
    public struct Step: Sendable {
      /// The test to be passed to an instance of ``Runner``.
      public var test: Test

      /// The action to perform with ``test``.
      public var action: Action
    }

    /// The graph of the steps in the runner plan.
    var stepGraph: Graph<String, Step?>

    /// The steps of the runner plan.
    public var steps: [Step] {
      stepGraph.compactMap(\.value).sorted { $0.test.sourceLocation < $1.test.sourceLocation }
    }

    /// Initialize an instance of this type with the specified graph of test
    /// plan steps.
    ///
    /// - Parameters:
    ///   - stepGraph: The steps of the runner plan.
    ///
    /// This is the designated initializer for this type.
    init(stepGraph: Graph<String, Step?>) {
      self.stepGraph = stepGraph
    }

    /// Initialize an instance of this type with the specified runner plan
    /// steps.
    ///
    /// - Parameters:
    ///   - steps: The steps of the runner plan.
    public init(steps: some Sequence<Step>) {
      var stepGraph = Graph<String, Step?>()
      for step in steps {
        let idComponents = step.test.id.keyPathRepresentation
        stepGraph.insertValue(step, at: idComponents)
      }
      self.init(stepGraph: stepGraph)
    }
  }
}

// MARK: - Constructing a new runner plan

extension Runner.Plan {
  /// Recursively apply eligible traits from a test suite to its children in a
  /// graph.
  ///
  /// - Parameters:
  ///   - parentTraits: The traits from the parent graph to recursively apply to
  ///     `testGraph`.
  ///   - testGraph: The graph of tests to modify.
  ///
  /// The traits in `testGraph.value?.traits` are added to each node in
  /// `testGraph`, and then this function is called recursively on each child
  /// node.
  private static func _recursivelyApplyTraits(_ parentTraits: [any Trait] = [], to testGraph: inout Graph<String, Test?>) {
    let traits: [any SuiteTrait] = (parentTraits + (testGraph.value?.traits ?? [])).lazy
      .compactMap { $0 as? any SuiteTrait }
      .filter(\.isRecursive)

    testGraph.children = testGraph.children.mapValues { child in
      var child = child
      _recursivelyApplyTraits(traits, to: &child)
      child.value?.traits.insert(contentsOf: traits, at: 0)
      return child
    }
  }

  /// Construct a graph of runner plan steps for the specified tests.
  ///
  /// - Parameters:
  ///   - tests: The tests for which a graph should be constructed.
  ///   - configuration: The configuration to use for planning.
  ///
  /// - Returns: A graph of the steps corresponding to `tests`.
  private static func _constructStepGraph(from tests: some Sequence<Test>, configuration: Configuration) async -> Graph<String, Step?> {
    // Ensure that we are capturing backtraces for errors before we start
    // expecting to see them.
    Backtrace.startCachingForThrownErrors()
    defer {
      Backtrace.flushThrownErrorCache()
    }

    // Convert the list of test into a graph of steps. The actions for these
    // steps will all be .run() *unless* an error was thrown while examining
    // them, in which case it will be .recordIssue().
    let runAction = Action.run(options: .init(isParallelizationEnabled: configuration.isParallelizationEnabled))
    var testGraph = Graph<String, Test?>()
    var actionGraph = Graph<String, Action>(value: runAction)
    for test in tests {
      let idComponents = test.id.keyPathRepresentation
      testGraph.insertValue(test, at: idComponents)
      actionGraph.insertValue(runAction, at: idComponents, intermediateValue: runAction)
    }

    // Ensure the trait lists are complete for all nested tests. (Make sure to
    // do this before we start calling configuration.testFilter or prepare(for:)
    // or we'll miss the recursively-added traits.)
    _recursivelyApplyTraits(to: &testGraph)

    // Remove any tests that should be filtered out per the runner's
    // configuration. The action graph is not modified here: actions that lose
    // their corresponding tests are effectively filtered out by the call to
    // zip() near the end of the function.
    do {
      testGraph = try configuration.testFilter.apply(to: testGraph)
    } catch {
      // FIXME: Handle this more gracefully, either by propagating the error
      // (which will ultimately require `Runner.init(...)` to be throwing:
      // rdar://126631222) or by recording a single `Issue` representing the
      // planning failure.
      //
      // For now, ignore the error and include all tests. As of this writing,
      // the only scenario where this will throw is when using regex filtering,
      // and that is already guarded earlier in the SwiftPM entry point.
    }

    // For each test value, determine the appropriate action for it.
    //
    // FIXME: Parallelize this work. Calling `prepare(...)` on all traits and
    // evaluating all test arguments should be safely parallelizable.
    testGraph = await testGraph.mapValues { keyPath, test in
      // Skip any nil test, which implies this node is just a placeholder and
      // not actual test content.
      guard var test else {
        return nil
      }

      var action = runAction
      var firstCaughtError: (any Error)?

      // Walk all the traits and tell each to prepare to run the test.
      // If any throw a `SkipInfo` error at this stage, stop walking further.
      // But if any throw another kind of error, keep track of the first error
      // but continue walking, because if any subsequent traits throw a
      // `SkipInfo`, the error should not be recorded.
      for trait in test.traits {
        do {
          if let trait = trait as? any SPIAwareTrait {
            try await trait.prepare(for: test, action: &action)
          } else {
            try await trait.prepare(for: test)
          }
        } catch let error as SkipInfo {
          action = .skip(error)
          break
        } catch {
          // Only preserve the first caught error
          firstCaughtError = firstCaughtError ?? error
        }
      }

      // If no trait specified that the test should be skipped, but one did
      // throw an error, then the action is to record an issue for that error.
      if case .run = action, let error = firstCaughtError {
        action = .recordIssue(Issue(for: error))
      }

      // If the test is still planned to run (i.e. nothing thus far has caused
      // it to be skipped), evaluate its test cases now.
      //
      // The argument expressions of each test are captured in closures so they
      // can be evaluated lazily only once it is determined that the test will
      // run, to avoid unnecessary work. But now is the appropriate time to
      // evaluate them.
      if case .run = action {
        do {
          try await test.evaluateTestCases()
        } catch {
          action = .recordIssue(Issue(for: error))
        }
      }

      // If the test is parameterized but has no cases, mark it as skipped.
      if case .run = action, let testCases = test.testCases, testCases.first(where: { _ in true }) == nil {
        action = .skip(SkipInfo(comment: "No test cases found."))
      }

      actionGraph.updateValue(action, at: keyPath)

      return test
    }

    // Now that we have allowed all the traits to update their corresponding
    // actions, recursively apply those actions to child tests in the graph.
    actionGraph = actionGraph.mapValues { _, action in
      (action, recursivelyApply: action.isRecursive)
    }

    // Zip the tests and actions together and return them.
    return zip(testGraph, actionGraph).mapValues { _, pair in
      pair.0.map { Step(test: $0, action: pair.1) }
    }
  }

  /// Initialize an instance of this type with the specified tests and
  /// configuration.
  ///
  /// - Parameters:
  ///   - tests: The tests for which a runner plan should be constructed.
  ///   - configuration: The configuration to use for planning.
  ///
  /// This function produces a new runner plan for the provided tests.
  public init(tests: some Sequence<Test>, configuration: Configuration) async {
    let stepGraph = await Self._constructStepGraph(from: tests, configuration: configuration)
    self.init(stepGraph: stepGraph)
  }

  /// Initialize an instance of this type that will run all tests found in the
  /// current process.
  ///
  /// - Parameters:
  ///   - configuration: The configuration to use for planning.
  public init(configuration: Configuration) async {
    await self.init(tests: Test.all, configuration: configuration)
  }
}

#if !SWT_NO_SNAPSHOT_TYPES
// MARK: - Snapshotting

extension Runner.Plan {
  /// A serializable snapshot of a ``Runner/Plan-swift.struct`` instance.
  @_spi(ForToolsIntegrationOnly)
  public struct Snapshot: Sendable {
    /// The graph of the steps in this runner plan.
    private var _stepGraph: Graph<String, Step.Snapshot?> = .init(value: nil)

    /// Initialize an instance of this type by snapshotting the specified plan.
    ///
    /// - Parameters:
    ///   - plan: The original plan to snapshot.
    public init(snapshotting plan: borrowing Runner.Plan) {
      plan.stepGraph.forEach { keyPath, step in
        let step = step.map(Step.Snapshot.init(snapshotting:))
        _stepGraph.insertValue(step, at: keyPath)
      }
    }

    /// The steps of this runner plan.
    public var steps: some Collection<Step.Snapshot> {
      _stepGraph.compactMap(\.value)
    }
  }
}

extension Runner.Plan.Snapshot: Codable {
  /// The coding keys used for serializing a
  /// ``Runner/Plan-swift.struct/Snapshot`` instance.
  private enum _CodingKeys: CodingKey {
    /// The tests contained by this plan, stored as an unkeyed container of
    /// ``Test/Snapshot`` instances.
    case tests
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: _CodingKeys.self)

    var testsContainer = try container.nestedUnkeyedContainer(forKey: .tests)

    // Decode elements incrementally, rather than all at once, to avoid needing
    // an array containing all tests.
    while !testsContainer.isAtEnd {
      let step = try testsContainer.decode(Runner.Plan.Step.Snapshot.self)
      let idComponents = step.test.id.keyPathRepresentation
      _stepGraph.insertValue(step, at: idComponents)
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: _CodingKeys.self)

    var testsContainer = container.nestedUnkeyedContainer(forKey: .tests)

    // Encode elements incrementally, rather than all at once, to avoid needing
    // an array containing all tests.
    try _stepGraph.forEach { _, step in
      guard let step else { return }
      try testsContainer.encode(step)
    }
  }
}

extension Runner.Plan.Step {
  /// A serializable snapshot of a ``Runner/Plan-swift.struct/Step`` instance.
  @_spi(ForToolsIntegrationOnly)
  public struct Snapshot: Sendable, Codable {
    /// The test referenced by this instance.
    public var test: Test.Snapshot

    /// The action to perform with ``test``.
    public var action: Runner.Plan.Action.Snapshot

    /// Initialize an instance of this type by snapshotting the specified step.
    ///
    /// - Parameters:
    ///   - step: The original step to snapshot.
    public init(snapshotting step: borrowing Runner.Plan.Step) {
      test = Test.Snapshot(snapshotting: step.test)
      action = Runner.Plan.Action.Snapshot(snapshotting: step.action)
    }
  }
}

extension Runner.Plan.Action {
  /// A serializable snapshot of a ``Runner/Plan-swift.struct/Step/Action``
  /// instance.
  @_spi(ForToolsIntegrationOnly)
  public enum Snapshot: Sendable, Codable {
    /// The test should be run.
    ///
    /// - Parameters:
    ///   - options: Options to apply to this action when it is run.
    case run(options: RunOptions)

    /// The test should be skipped.
    ///
    /// - Parameters:
    ///   - skipInfo: A ``SkipInfo`` representing the details of this skip.
    case skip(_ skipInfo: SkipInfo)

    /// The test should record an issue due to a failure during
    /// planning.
    ///
    /// - Parameters:
    ///   - issue: A snapshot of the issue representing the failure encountered
    ///     during planning.
    case recordIssue(_ issue: Issue.Snapshot)

    /// Initialize an instance of this type by snapshotting the specified
    /// action.
    ///
    /// - Parameters:
    ///   - action: The original action to snapshot.
    public init(snapshotting action: Runner.Plan.Action) {
      self = switch action {
      case let .run(options):
        .run(options: options)
      case let .skip(skipInfo):
        .skip(skipInfo)
      case let .recordIssue(issue):
        .recordIssue(Issue.Snapshot(snapshotting: issue))
      }
    }
  }
}
#endif

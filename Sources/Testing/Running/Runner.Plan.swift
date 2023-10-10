//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(ExperimentalTestRunning)
extension Runner {
  /// A type describing a runner plan.
  public struct Plan: Sendable {
    /// The action to perform for a test in this plan.
    public enum Action: Sendable {
      /// The test should be run.
      case run

      /// The test should be skipped.
      ///
      /// - Parameters:
      ///   - skipInfo: A ``SkipInfo`` representing the details of this skip.
      case skip(_ skipInfo: SkipInfo = .init())

      /// The test should record an issue due to a failure during
      /// planning.
      ///
      /// - Parameters:
      ///   - issue: An issue representing the failure encountered during
      ///     planning.
      case recordIssue(_ issue: Issue)

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
    }

    /// A type describing a step in a runner plan.
    ///
    /// An instance of this type contains a test and the corresponding action an
    /// instance of ``Runner`` should perform for that test.
    public struct Step: Sendable {
      /// The test to be passed to an instance of ``Runner``.
      public var test: Test

      /// The action to perform with ``Test/Plan/Step/test``.
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

@_spi(ExperimentalTestRunning)
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

  /// Determine if a test is included in the selected test IDs, if any are
  /// configured.
  ///
  /// - Parameters:
  ///   - test: The test to query.
  ///   - selectedTests: The selected test IDs to use in determining whether
  ///     `test` is selected, if one is configured.
  ///   - filter: The filter to decide if the test is included.
  ///
  /// - Returns: Whether or not the specified test is selected. If
  ///   `selectedTests` is `nil`, `test` is considered selected if it is not
  ///   hidden.
  private static func _isTestIncluded(_ test: Test, using filter: Configuration.TestFilter?) -> Bool {
    guard let filter else {
      return !test.isHidden
    }
    return filter(test)
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
    var testGraph = Graph<String, Test?>()
    var actionGraph = Graph<String, Action>(value: .run)
    for test in tests where _isTestIncluded(test, using: configuration.testFilter) {
      let idComponents = test.id.keyPathRepresentation
      testGraph.insertValue(test, at: idComponents)
      actionGraph.insertValue(.run, at: idComponents, intermediateValue: .run)
    }

    // Ensure the trait lists are complete for all nested tests. (Make sure to
    // do this before we start calling prepare(for:) or we'll miss the
    // recursively-added ones.)
    _recursivelyApplyTraits(to: &testGraph)

    // For each test value, determine the appropriate action for it.
    await testGraph.forEach { keyPath, test in
      // Skip any nil test, which implies this node is just a placeholder and
      // not actual test content.
      guard let test else {
        return
      }

      var action = Action.run
      var firstCaughtError: (any Error)?

      // Walk all the traits and tell each to prepare to run the test.
      // If any throw a `SkipInfo` error at this stage, stop walking further.
      // But if any throw another kind of error, keep track of the first error
      // but continue walking, because if any subsequent traits throw a
      // `SkipInfo`, the error should not be recorded.
      for trait in test.traits {
        do {
          try await trait.prepare(for: test)
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
        let sourceContext = SourceContext(backtrace: Backtrace(forFirstThrowOf: error))
        let issue = Issue(kind: .errorCaught(error), comments: [], sourceContext: sourceContext)
        action = .recordIssue(issue)
      }

      actionGraph.updateValue(action, at: keyPath)
    }

    // Now that we have allowed all the traits to update their corresponding
    // actions, recursively apply those actions to child tests in the graph.
    actionGraph = actionGraph.mapValues { action in
      (action, recursivelyApply: action.isRecursive)
    }

    // Zip the tests and actions together and return them.
    return zip(testGraph, actionGraph).mapValues { test, action in
      test.map { Step(test: $0, action: action) }
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

// MARK: - Parallelization support

extension Runner.Plan {
  /// Get the steps in a test graph that can run independently of each other.
  ///
  /// - Parameters:
  ///   - stepGraph: The step graph to recursively examine.
  ///
  /// - Returns: The steps in `stepGraph` that can run independently of each
  ///   other.
  ///
  /// For more information, see ``independentlyRunnableSteps``.
  private func _independentlyRunnableSteps(in stepGraph: Graph<String, Step?>) -> [Step] {
    if let step = stepGraph.value {
      return [step]
    }
    return stepGraph.children.reduce(into: []) { result, childStepGraph in
      result += _independentlyRunnableSteps(in: childStepGraph.value)
    }
  }

  /// The steps of the runner plan that can run independently of each other.
  ///
  /// If a test is a child of another test, then it is dependent on that test
  /// to run. The value of this property is the set of steps that are _not_
  /// dependent on each other. For example, given the following structure:
  ///
  /// ```swift
  /// struct A {
  ///   @Suite struct B {
  ///     @Test func c() {}
  ///     @Test func d() {}
  ///   struct E {
  ///     @Test func f() {}
  ///   }
  /// }
  /// ```
  ///
  /// Only `B` and `E` are fully independent of any other tests. `c()` and
  /// `d()` are independent of each other, but both are dependent on `B`, and
  /// `f()` is dependent on `E`.
  public var independentlyRunnableSteps: [Step] {
    _independentlyRunnableSteps(in: stepGraph)
  }
}

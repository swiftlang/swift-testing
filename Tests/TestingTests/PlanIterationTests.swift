//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

#if !SWT_TARGET_OS_APPLE && canImport(Synchronization)
import Synchronization
#endif

@Suite("Configuration.RepetitionPolicy Tests")
struct TestCaseIterationTests {
  @Test("One iteration (default behavior)")
  func oneIteration() async {
    await confirmation("1 iteration started") { started in
      await confirmation("1 iteration ended") { ended in
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
          #expect(Bool.random())
        }.run(configuration: configuration)
      }
    }
  }

  @Test("Iteration until issue recorded")
  func iterationUntilIssueRecorded() async {
    let iterations = Atomic(0)
    let iterationCount = 10
    let iterationWithIssue = 5
    await confirmation("N iterations started", expectedCount: iterationWithIssue + 1) { started in
      await confirmation("N iterations ended", expectedCount: iterationWithIssue + 1) { ended in
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
          #expect(iterations <= iterationWithIssue)
        }.run(configuration: configuration)
      }
    }
  }

  @Test("Iteration while issue recorded")
  func iterationWhileIssueRecorded() async {
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
          #expect(iterations >= iterationWithoutIssue)
        }.run(configuration: configuration)
      }
    }
  }

  @Test
  func iterationOnlyRepeatsFailingTest() async {
    let iterationForFailingTest = Atomic(0)
    let iterationForSucceedingTest = Atomic(0)

    let iterationCount = 10
    let iterationWithoutIssue = 5

    var configuration = Configuration()
    configuration.eventHandler = { event, context in
      guard
        let test = context.test,
        let iteration = context.iteration,
        case .testCaseStarted = event.kind else {
        return
      }
      if test.name.contains("Failing") {
        iterationForFailingTest.store(iteration, ordering: .sequentiallyConsistent)
      }
      if test.name.contains("Succeeding") {
        iterationForSucceedingTest.store(iteration, ordering: .sequentiallyConsistent)
      }
    }
    configuration.repetitionPolicy = .repeating(.whileIssueRecorded, maximumIterationCount: iterationCount)

    let runner = await Runner(testing: [
      Test(name: "Failing") {
        let iteration = iterationForFailingTest.load(ordering: .sequentiallyConsistent)
        #expect(iteration >= iterationWithoutIssue)
      },
      Test(name: "Succeeding") {
        #expect(Bool(true))
      },

    ], configuration: configuration)

    await runner.run()

    let failureIteration = iterationForFailingTest.load(ordering: .sequentiallyConsistent)
    #expect(failureIteration == iterationWithoutIssue)

    let successIteration = iterationForSucceedingTest.load(ordering: .sequentiallyConsistent)
    #expect(successIteration == 1)
  }

#if !SWT_NO_EXIT_TESTS
  @Test("Iteration count must be positive")
  func positiveIterationCount() async {
    await #expect(processExitsWith: .failure) {
      var configuration = Configuration()
      configuration.repetitionPolicy.maximumIterationCount = 0
    }
    await #expect(processExitsWith: .failure) {
      var configuration = Configuration()
      configuration.repetitionPolicy.maximumIterationCount = -1
    }
  }
#endif
}

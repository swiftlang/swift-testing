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

@Suite
struct TestCaseIterationTests {
  @Test("One iteration (default behavior)")
  func oneIteration() async {
    await confirmation("N iterations started") { started in
      await confirmation("N iterations ended") { ended in
        var configuration = Configuration()
        configuration.shouldUseLegacyPlanLevelRepetition = false
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
        configuration.shouldUseLegacyPlanLevelRepetition = false
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
        configuration.shouldUseLegacyPlanLevelRepetition = false
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

  @Test("Iteration while issue recorded")
  func iterationWhileIssueRecorded() async {
    let iterations = Atomic(0)
    let iterationCount = 10
    let iterationWithoutIssue = 5
    await confirmation("N iterations started", expectedCount: iterationWithoutIssue) { started in
      await confirmation("N iterations ended", expectedCount: iterationWithoutIssue) { ended in
        var configuration = Configuration()
        configuration.shouldUseLegacyPlanLevelRepetition = false
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
}

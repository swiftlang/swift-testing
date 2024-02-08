//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ExperimentalTestRunning) @_spi(ExperimentalEventHandling) import Testing

@Suite("Configuration.IterationPolicy Tests")
struct PlanIterationTests {
  @Test("One iteration (default behavior)")
  func oneIteration() async {
    await confirmation("N iterations started") { started in
      await confirmation("N iterations ended") { ended in
        var configuration = Configuration()
        configuration.eventHandler = { event, _ in
          if case .iterationStarted = event.kind {
            started()
          } else if case .iterationEnded = event.kind {
            ended()
          }
        }
        configuration.iterationPolicy = .once

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
          if case .iterationStarted = event.kind {
            started()
          } else if case .iterationEnded = event.kind {
            ended()
          }
        }
        configuration.iterationPolicy = .repeating(count: iterationCount)

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
    let iterationIndex = Locked(rawValue: 0)
    let iterationCount = 10
    let iterationWithIssue = 5
    await confirmation("N iterations started", expectedCount: iterationWithIssue + 1) { started in
      await confirmation("N iterations ended", expectedCount: iterationWithIssue + 1) { ended in
        var configuration = Configuration()
        configuration.eventHandler = { event, _ in
          if case let .iterationStarted(index) = event.kind {
            iterationIndex.withLock { iterationIndex in
              iterationIndex = index
            }
            started()
          } else if case .iterationEnded = event.kind {
            ended()
          }
        }
        configuration.iterationPolicy = .repeating(.untilIssueRecorded, count: iterationCount)

        await Test {
          if iterationIndex.rawValue == iterationWithIssue {
            #expect(Bool(false))
          }
        }.run(configuration: configuration)
      }
    }
  }

  @Test("Iteration while issue recorded")
  func iterationWhileIssueRecorded() async {
    let iterationIndex = Locked(rawValue: 0)
    let iterationCount = 10
    let iterationWithoutIssue = 5
    await confirmation("N iterations started", expectedCount: iterationWithoutIssue + 1) { started in
      await confirmation("N iterations ended", expectedCount: iterationWithoutIssue + 1) { ended in
        var configuration = Configuration()
        configuration.eventHandler = { event, _ in
          if case let .iterationStarted(index) = event.kind {
            iterationIndex.withLock { iterationIndex in
              iterationIndex = index
            }
            started()
          } else if case .iterationEnded = event.kind {
            ended()
          }
        }
        configuration.iterationPolicy = .repeating(.whileIssueRecorded, count: iterationCount)

        await Test {
          if iterationIndex.rawValue < iterationWithoutIssue {
            #expect(Bool(false))
          }
        }.run(configuration: configuration)
      }
    }
  }
}

//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ExperimentalEventHandling) @_spi(ExperimentalTestRunning) import Testing

@Suite("Confirmation Tests")
struct ConfirmationTests {
  @Test("Successful confirmations")
  func successfulConfirmations() async {
    await confirmation("Issue recorded", expectedCount: 0) { issueRecorded in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case .issueRecorded = event.kind {
          issueRecorded()
        }
      }
      let testPlan = await Runner.Plan(selecting: SuccessfulConfirmationTests.self)
      let runner = Runner(plan: testPlan, configuration: configuration)
      await runner.run()
    }
  }

  @Test("Unsuccessful confirmations")
  func unsuccessfulConfirmations() async {
    await confirmation("Issue recorded", expectedCount: 3) { issueRecorded in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case let .issueRecorded(issue) = event.kind,
           case .confirmationMiscounted = issue.kind {
          issueRecorded()
        }
      }
      let testPlan = await Runner.Plan(selecting: UnsuccessfulConfirmationTests.self)
      let runner = Runner(plan: testPlan, configuration: configuration)
      await runner.run()
    }
  }
}

// MARK: - Fixtures

@Suite(.hidden)
struct SuccessfulConfirmationTests {
  @Test(.hidden)
  func basicConfirmation() async {
    await confirmation { (thingHappened) async in
      thingHappened()
    }
  }

  @Test(.hidden)
  func confirmed0Times() async {
    await confirmation(expectedCount: 0) { (_) async in }
  }

  @Test(.hidden)
  func confirmed3Times() async {
    await confirmation(expectedCount: 3) { (thingHappened) async in
      thingHappened(count: 3)
    }
  }
}

@Suite(.hidden)
struct UnsuccessfulConfirmationTests {
  @Test(.hidden)
  func basicConfirmation() async {
    await confirmation { (_) async in }
  }

  @Test(.hidden)
  func confirmedTooFewTimes() async {
    await confirmation(expectedCount: 3) { (thingHappened) async in
      thingHappened(count: 2)
    }
  }

  @Test(.hidden)
  func confirmedTooManyTimes() async {
    await confirmation(expectedCount: 3) { (thingHappened) async in
      thingHappened(count: 10)
    }
  }
}

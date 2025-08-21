//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

struct `Test cancellation tests` {
  func testCancellation(testCancelled: Int = 0, testSkipped: Int = 0, testCaseCancelled: Int = 0, issueRecorded: Int = 0, _ body: @Sendable (Configuration) async -> Void) async {
    await confirmation("Test cancelled", expectedCount: testCancelled) { testCancelled in
      await confirmation("Test skipped", expectedCount: testSkipped) { testSkipped in
        await confirmation("Test case cancelled", expectedCount: testCaseCancelled) { testCaseCancelled in
          await confirmation("Issue recorded", expectedCount: issueRecorded) { issueRecorded in
            var configuration = Configuration()
            configuration.eventHandler = { event, _ in
              switch event.kind {
              case .testCancelled:
                testCancelled()
              case .testSkipped:
                testSkipped()
              case .testCaseCancelled:
                testCaseCancelled()
              case .issueRecorded:
                issueRecorded()
              default:
                break
              }
            }
            await body(configuration)
          }
        }
      }
    }
  }

  @Test func `Cancelling a test`() async {
    await testCancellation(testCancelled: 1) { configuration in
      await Test {
        try Test.cancel("Cancelled test")
      }.run(configuration: configuration)
    }
  }

  @Test func `Cancelling a non-parameterized test via Test.Case.cancel()`() async {
    await testCancellation(testCancelled: 1) { configuration in
      await Test {
        try Test.Case.cancel("Cancelled test")
      }.run(configuration: configuration)
    }
  }

  @Test func `Cancelling a test case in a parameterized test`() async {
    await testCancellation(testCaseCancelled: 5, issueRecorded: 5) { configuration in
      await Test(arguments: 0 ..< 10) { i in
        if (i % 2) == 0 {
          try Test.Case.cancel("\(i) is even!")
        }
        Issue.record("\(i) records an issue!")
      }.run(configuration: configuration)
    }
  }

  @Test func `Cancelling an entire parameterized test`() async {
    await testCancellation(testCancelled: 1) { configuration in
      // .serialized to ensure that none of the cases complete before the first
      // one cancels the test.
      await Test(.serialized, arguments: 0 ..< 10) { i in
        if i == 0 {
          try Test.cancel("\(i) cancelled the test")
        }
        Issue.record("\(i) records an issue!")
      }.run(configuration: configuration)
    }
  }

  struct CancelledTrait: TestTrait {
    func prepare(for test: Test) async throws {
      try Test.cancel("Cancelled from trait")
    }
  }

  @Test func `Cancelling a test case while evaluating traits skips the test`() async {
    await testCancellation(testSkipped: 1) { configuration in
      await Test(CancelledTrait()) {
        Issue.record("Recorded an issue!")
      }.run(configuration: configuration)
    }
  }
}

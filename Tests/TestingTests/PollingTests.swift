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

@Suite("Polling Tests")
struct PollingTests {
  @Suite("confirmPassesEventually")
  struct PassesOnceBehavior {
    @Test("Simple passing expressions") func trivialHappyPath() async throws {
      await confirmPassesEventually { true }
      try await requirePassesEventually { true }

      let value = try await confirmPassesEventually { 1 }

      #expect(value == 1)
    }

    @Test("Simple failing expressions") func trivialSadPath() async throws {
      let issues = await runTest {
        await confirmPassesEventually { false }
        _ = try await confirmPassesEventually { Optional<Int>.none }
        await #expect(throws: PollingFailedError()) {
          try await requirePassesEventually { false }
        }
      }
      #expect(issues.count == 3)
    }

    @Test("When the value changes from false to true during execution") func changingFromFail() async {
      let incrementor = Incrementor()

      await confirmPassesEventually {
        await incrementor.increment() == 2
        // this will pass only on the second invocation
        // This checks that we really are only running the expression until
        // the first time it passes.
      }

      // and then we check the count just to double check.
      #expect(await incrementor.count == 2)
    }

    @Test("Thrown errors are treated as returning false")
    func errorsReported() async {
      let issues = await runTest {
        await confirmPassesEventually {
          throw PollingTestSampleError.ohNo
        }
      }
      #expect(issues.count == 1)
    }

    @Test("Calculates how many times to poll based on the duration & interval")
    func defaultPollingCount() async {
      let incrementor = Incrementor()
      _ = await runTest {
        // this test will intentionally fail.
        await confirmPassesEventually(pollingInterval: .milliseconds(1)) {
          await incrementor.increment() == 0
        }
      }
      #expect(await incrementor.count == 1000)
    }

    @Suite(
      "Configuration traits",
      .confirmPassesEventuallyDefaults(pollingDuration: .milliseconds(100))
    )
    struct WithConfigurationTraits {
      @Test("When no test or callsite configuration provided, uses the suite configuration")
      func testUsesSuiteConfiguration() async throws {
        let incrementor = Incrementor()
        var test = Test {
          await confirmPassesEventually(pollingInterval: .milliseconds(1)) {
            await incrementor.increment() == 0
          }
        }
        test.traits = Test.current?.traits ?? []
        await runTest(test: test)
        let count = await incrementor.count
        #expect(count == 100)
      }

      @Test(
        "When test configuration provided, uses the test configuration",
        .confirmPassesEventuallyDefaults(pollingDuration: .milliseconds(10))
      )
      func testUsesTestConfigurationOverSuiteConfiguration() async {
        let incrementor = Incrementor()
        var test = Test {
          // this test will intentionally fail.
          await confirmPassesEventually(pollingInterval: .milliseconds(1)) {
            await incrementor.increment() == 0
          }
        }
        test.traits = Test.current?.traits ?? []
        await runTest(test: test)
        #expect(await incrementor.count == 10)
      }

      @Test(
        "When callsite configuration provided, uses that",
        .confirmPassesEventuallyDefaults(pollingDuration: .milliseconds(10))
      )
      func testUsesCallsiteConfiguration() async {
        let incrementor = Incrementor()
        var test = Test {
          // this test will intentionally fail.
          await confirmPassesEventually(
            pollingDuration: .milliseconds(50),
            pollingInterval: .milliseconds(1)
          ) {
            await incrementor.increment() == 0
          }
        }
        test.traits = Test.current?.traits ?? []
        await runTest(test: test)
        #expect(await incrementor.count == 50)
      }

#if !SWT_NO_EXIT_TESTS
      @Test("Requires duration be greater than interval")
      func testRequiresDurationGreaterThanInterval() async {
        await #expect(processExitsWith: .failure) {
          await confirmPassesEventually(
            pollingDuration: .seconds(1),
            pollingInterval: .milliseconds(1100)
          ) { true }
        }
      }

      @Test("Requires duration be greater than 0")
      func testRequiresDurationGreaterThan0() async {
        await #expect(processExitsWith: .failure) {
          await confirmPassesEventually(pollingDuration: .seconds(0)) { true }
        }
      }

      @Test("Requires interval be greater than 0")
      func testRequiresIntervalGreaterThan0() async {
        await #expect(processExitsWith: .failure) {
          await confirmPassesEventually(pollingInterval: .seconds(0)) { true }
        }
      }
#endif
    }
  }

  @Suite("confirmAlwaysPasses")
  struct PassesAlwaysBehavior {
    @Test("Simple passing expressions") func trivialHappyPath() async throws {
      await confirmAlwaysPasses { true }
      try await requireAlwaysPasses { true }
    }

    @Test("Simple failing expressions") func trivialSadPath() async {
      let issues = await runTest {
        await confirmAlwaysPasses { false }
        await #expect(throws: PollingFailedError()) {
          try await requireAlwaysPasses { false }
        }
      }
      #expect(issues.count == 1)
    }

    @Test("if the closures starts off as true, but becomes false")
    func changingFromFail() async {
      let incrementor = Incrementor()
      let issues = await runTest {
        await confirmAlwaysPasses {
          await incrementor.increment() == 2
          // this will pass only on the first invocation
          // This checks that we fail the test if it starts failing later during
          // polling
        }
      }
      #expect(issues.count == 1)
    }

    @Test("if the closure continues to pass")
    func continuousCalling() async {
      let incrementor = Incrementor()

      await confirmAlwaysPasses {
        _ = await incrementor.increment()
        return true
      }

      #expect(await incrementor.count > 1)
    }

    @Test("Thrown errors will automatically exit & fail")
    func errorsReported() async {
      let issues = await runTest {
        await confirmAlwaysPasses {
          throw PollingTestSampleError.ohNo
        }
      }
      #expect(issues.count == 1)
    }

    @Test("Calculates how many times to poll based on the duration & interval")
    func defaultPollingCount() async {
      let incrementor = Incrementor()
      await confirmAlwaysPasses(pollingInterval: .milliseconds(1)) {
        await incrementor.increment() != 0
      }
      #expect(await incrementor.count == 1000)
    }

    @Suite(
      "Configuration traits",
      .confirmAlwaysPassesDefaults(pollingDuration: .milliseconds(100))
    )
    struct WithConfigurationTraits {
      @Test(
        "When no test/callsite configuration, it uses the suite configuration"
      )
      func testUsesSuiteConfiguration() async throws {
        let incrementor = Incrementor()
        await confirmAlwaysPasses(pollingInterval: .milliseconds(1)) {
          await incrementor.increment() != 0
        }
        let count = await incrementor.count
        #expect(count == 100)
      }

      @Test(
        "When test configuration porvided, uses the test configuration",
        .confirmAlwaysPassesDefaults(pollingDuration: .milliseconds(10))
      )
      func testUsesTestConfigurationOverSuiteConfiguration() async {
        let incrementor = Incrementor()
        await confirmAlwaysPasses(pollingInterval: .milliseconds(1)) {
          await incrementor.increment() != 0
        }
        #expect(await incrementor.count == 10)
      }

      @Test(
        "When callsite configuration provided, uses that",
        .confirmAlwaysPassesDefaults(pollingDuration: .milliseconds(10))
      )
      func testUsesCallsiteConfiguration() async {
        let incrementor = Incrementor()
        await confirmAlwaysPasses(
          pollingDuration: .milliseconds(50),
          pollingInterval: .milliseconds(1)
        ) {
          await incrementor.increment() != 0
        }
        #expect(await incrementor.count == 50)
      }

#if !SWT_NO_EXIT_TESTS
      @Test("Requires duration be greater than interval")
      func testRequiresDurationGreaterThanInterval() async {
        await #expect(processExitsWith: .failure) {
          await confirmAlwaysPasses(
            pollingDuration: .seconds(1),
            pollingInterval: .milliseconds(1100)
          ) { true }
        }
      }

      @Test("Requires duration be greater than 0")
      func testRequiresDurationGreaterThan0() async {
        await #expect(processExitsWith: .failure) {
          await confirmAlwaysPasses(pollingDuration: .seconds(0)) { true }
        }
      }

      @Test("Requires interval be greater than 0")
      func testRequiresIntervalGreaterThan0() async {
        await #expect(processExitsWith: .failure) {
          await confirmAlwaysPasses(pollingInterval: .seconds(0)) { true }
        }
      }
#endif
    }
  }

  @Suite("Duration Tests", .disabled("time-sensitive"))
  struct DurationTests {
    @Suite("confirmPassesEventually")
    struct PassesOnceBehavior {
      let delta = Duration.milliseconds(100)

      @Test("Simple passing expressions") func trivialHappyPath() async {
        let duration = await Test.Clock().measure {
          await confirmPassesEventually { true }
        }
        #expect(duration.isCloseTo(other: .zero, within: delta))
      }

      @Test("Simple failing expressions") func trivialSadPath() async {
        let duration = await Test.Clock().measure {
          let issues = await runTest {
            await confirmPassesEventually { false }
          }
          #expect(issues.count == 1)
        }
        #expect(duration.isCloseTo(other: .seconds(2), within: delta))
      }

      @Test("When the value changes from false to true during execution")
      func changingFromFail() async {
        let incrementor = Incrementor()

        let duration = await Test.Clock().measure {
          await confirmPassesEventually {
            await incrementor.increment() == 2
            // this will pass only on the second invocation
            // This checks that we really are only running the expression until
            // the first time it passes.
          }
        }

        // and then we check the count just to double check.
        #expect(await incrementor.count == 2)
        #expect(duration.isCloseTo(other: .zero, within: delta))
      }

      @Test("Doesn't wait after the last iteration")
      func lastIteration() async {
        let duration = await Test.Clock().measure {
          let issues = await runTest {
            await confirmPassesEventually(
              pollingDuration: .seconds(10),
              pollingInterval: .seconds(1) // Wait a long time to handle jitter.
            ) { false }
          }
          #expect(issues.count == 1)
        }
        #expect(
          duration.isCloseTo(
            other: .seconds(9),
            within: .milliseconds(500)
          )
        )
      }
    }

    @Suite("confirmAlwaysPasses")
    struct PassesAlwaysBehavior {
      let delta = Duration.milliseconds(100)

      @Test("Simple passing expressions") func trivialHappyPath() async {
        let duration = await Test.Clock().measure {
          await confirmAlwaysPasses { true }
        }
        #expect(duration.isCloseTo(other: .seconds(2), within: delta))
      }

      @Test("Simple failing expressions") func trivialSadPath() async {
        let duration = await Test.Clock().measure {
          let issues = await runTest {
            await confirmAlwaysPasses { false }
          }
          #expect(issues.count == 1)
        }
        #expect(duration.isCloseTo(other: .zero, within: delta))
      }

      @Test("Doesn't wait after the last iteration")
      func lastIteration() async {
        let duration = await Test.Clock().measure {
          await confirmAlwaysPasses(
            pollingDuration: .seconds(10),
            pollingInterval: .seconds(1) // Wait a long time to handle jitter.
          ) { true }
        }
        #expect(
          duration.isCloseTo(
            other: .seconds(9),
            within: .milliseconds(500)
          )
        )
      }
    }
  }
}

private enum PollingTestSampleError: Error {
  case ohNo
  case secondCase
}

extension DurationProtocol {
  fileprivate func isCloseTo(other: Self, within delta: Self) -> Bool {
    var distance = self - other
    if (distance < Self.zero) {
      distance *= -1
    }
    return distance <= delta
  }
}

private actor Incrementor {
  var count = 0
  func increment() -> Int {
    count += 1
    return count
  }
}

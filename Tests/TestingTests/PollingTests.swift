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
    let delta = Duration.seconds(6)

    @Test("Simple passing expressions") func trivialHappyPath() async throws {
      await confirmPassesEventually { true }

      let value = try await confirmPassesEventually { 1 }
      #expect(value == 1)
    }

    @Test("Simple failing expressions") func trivialSadPath() async throws {
      let issues = await runTest {
        await confirmPassesEventually { false }
        _ = try await confirmPassesEventually { Optional<Int>.none }
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
  }

  @Suite("confirmAlwaysPasses")
  struct PassesAlwaysBehavior {
    // use a very generous delta for CI reasons.
    let delta = Duration.seconds(6)

    @Test("Simple passing expressions") func trivialHappyPath() async {
      await confirmAlwaysPasses { true }
    }

    @Test("Returning value returns the last value from the expression")
    func returnsLastValueReturned() async throws {
      let incrementor = Incrementor()
      let value = try await confirmAlwaysPasses {
        await incrementor.increment()
      }
      #expect(value > 1)
    }

    @Test("Simple failing expressions") func trivialSadPath() async {
      let issues = await runTest {
        await confirmAlwaysPasses { false }
        _ = try await confirmAlwaysPasses { Optional<Int>.none }
      }
      #expect(issues.count == 3)
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

    @Test("Thrown errors will automatically exit & fail") func errorsReported() async {
      let issues = await runTest {
        await confirmAlwaysPasses {
          throw PollingTestSampleError.ohNo
        }
      }
      #expect(issues.count == 1)
    }
  }

  @Suite("Duration Tests", .disabled("time-sensitive")) struct DurationTests {
    @Suite("confirmPassesEventually")
    struct PassesOnceBehavior {
      let delta = Duration.seconds(6)

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
        #expect(duration.isCloseTo(other: .seconds(60), within: delta))
      }

      @Test("When the value changes from false to true during execution") func changingFromFail() async {
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
    }

    @Suite("confirmAlwaysPasses")
    struct PassesAlwaysBehavior {
      // use a very generous delta for CI reasons.
      let delta = Duration.seconds(6)

      @Test("Simple passing expressions") func trivialHappyPath() async {
        let duration = await Test.Clock().measure {
          await confirmAlwaysPasses { true }
        }
        #expect(duration.isCloseTo(other: .seconds(60), within: delta))
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

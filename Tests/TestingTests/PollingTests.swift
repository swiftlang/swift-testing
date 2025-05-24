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
  @Suite("PollingBehavior.passesOnce")
  struct PassesOnceBehavior {
    let delta = Duration.seconds(6)

    @Test("Simple passing expressions") func trivialHappyPath() async {
      await #expect(until: .passesOnce) { true }

      await #expect(until: .passesOnce, throws: PollingTestSampleError.ohNo) {
        throw PollingTestSampleError.ohNo
      }

      await #expect(until: .passesOnce, performing: {
        throw PollingTestSampleError.secondCase
      }, throws: { error in
        (error as? PollingTestSampleError) == .secondCase
      })

      await #expect(until: .passesOnce, throws: PollingTestSampleError.ohNo) {
        throw PollingTestSampleError.ohNo
      }
    }

    @Test("Simple failing expressions") func trivialSadPath() async {
      await confirmation("Polling failed", expectedCount: 1) { failed in
        var configuration = Configuration()
        configuration.eventHandler = { event, _ in
          if case .issueRecorded = event.kind {
            failed()
          }
        }
        await Test {
          await #expect(until: .passesOnce) { false }
        }.run(configuration: configuration)
      }
    }

    @Test("When the value changes from false to true during execution") func changingFromFail() async {
      let incrementor = Incrementor()

      await #expect(until: .passesOnce) {
        await incrementor.increment() == 2
        // this will pass only on the second invocation
        // This checks that we really are only running the expression until
        // the first time it passes.
      }

      // and then we check the count just to double check.
      #expect(await incrementor.count == 2)
    }

    @Test("Unexpected Errors are treated as returning false")
    func errorsReported() async {
      await confirmation("Polling failed", expectedCount: 1) { failed in
        var configuration = Configuration()
        configuration.eventHandler = { event, _ in
          if case .issueRecorded = event.kind {
            failed()
          }
        }
        await Test {
          await #expect(until: .passesOnce) {
            throw PollingTestSampleError.ohNo
          }
        }.run(configuration: configuration)
      }
    }
  }

  @Suite("PollingBehavior.passesAlways")
  struct PassesAlwaysBehavior {
    // use a very generous delta for CI reasons.
    let delta = Duration.seconds(6)

    @Test("Simple passing expressions") func trivialHappyPath() async {
      await #expect(until: .passesAlways) { true }
    }

    @Test("Simple failing expressions") func trivialSadPath() async {
      await confirmation("Polling failed", expectedCount: 1) { failed in
        var configuration = Configuration()
        configuration.eventHandler = { event, _ in
          if case .issueRecorded = event.kind {
            failed()
          }
        }
        await Test {
          await #expect(until: .passesAlways) { false }
        }.run(configuration: configuration)
      }
    }

    @Test("if the closures starts off as false, but would become true")
    func changingFromFail() async {
      let incrementor = Incrementor()

      await confirmation("Polling failed", expectedCount: 1) { failed in
        var configuration = Configuration()
        configuration.eventHandler = { event, _ in
          if case .issueRecorded = event.kind {
            failed()
          }
        }
        await Test {
          await #expect(until: .passesAlways) {
            await incrementor.increment() == 2
            // this will pass only on the second invocation
            // This checks that we fail the test if it immediately returns false
          }
        }.run(configuration: configuration)
      }

      #expect(await incrementor.count == 1)
    }

    @Test("if the closure continues to pass")
    func continuousCalling() async {
      let incrementor = Incrementor()

      await #expect(until: .passesAlways) {
        _ = await incrementor.increment()
        return true
      }

      #expect(await incrementor.count > 1)
    }

    @Test("Unexpected Errors will automatically exit & fail") func errorsReported() async {
      await confirmation("Polling failed", expectedCount: 1) { failed in
        var configuration = Configuration()
        configuration.eventHandler = { event, _ in
          if case .issueRecorded = event.kind {
            failed()
          }
        }
        await Test {
          await #expect(until: .passesAlways) {
            throw PollingTestSampleError.ohNo
          }
        }.run(configuration: configuration)
      }
    }
  }

  @Suite("Duration Tests", .disabled("time-sensitive")) struct DurationTests {
    @Suite("PollingBehavior.passesOnce")
    struct PassesOnceBehavior {
      let delta = Duration.seconds(6)

      @Test("Simple passing expressions") func trivialHappyPath() async {
        let duration = await Test.Clock().measure {
          await #expect(until: .passesOnce) { true }

          await #expect(until: .passesOnce, throws: PollingTestSampleError.ohNo) {
            throw PollingTestSampleError.ohNo
          }

          await #expect(until: .passesOnce, performing: {
            throw PollingTestSampleError.secondCase
          }, throws: { error in
            (error as? PollingTestSampleError) == .secondCase
          })

          await #expect(until: .passesOnce, throws: PollingTestSampleError.ohNo) {
            throw PollingTestSampleError.ohNo
          }
        }
        #expect(duration.isCloseTo(other: .zero, within: delta))
      }

      @Test("Simple failing expressions") func trivialSadPath() async {
        let duration = await Test.Clock().measure {
          await confirmation("Polling failed", expectedCount: 1) { failed in
            var configuration = Configuration()
            configuration.eventHandler = { event, _ in
              if case .issueRecorded = event.kind {
                failed()
              }
            }
            await Test {
              await #expect(until: .passesOnce) { false }
            }.run(configuration: configuration)
          }
        }
        #expect(duration.isCloseTo(other: .seconds(60), within: delta))
      }

      @Test("When the value changes from false to true during execution") func changingFromFail() async {
        let incrementor = Incrementor()

        let duration = await Test.Clock().measure {
          await #expect(until: .passesOnce) {
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

      @Test("Unexpected Errors are treated as returning false")
      func errorsReported() async {
        let duration = await Test.Clock().measure {
          await confirmation("Polling failed", expectedCount: 1) { failed in
            var configuration = Configuration()
            configuration.eventHandler = { event, _ in
              if case .issueRecorded = event.kind {
                failed()
              }
            }
            await Test {
              await #expect(until: .passesOnce) {
                throw PollingTestSampleError.ohNo
              }
            }.run(configuration: configuration)
          }
        }
        #expect(duration.isCloseTo(other: .seconds(60), within: delta))
      }
    }

    @Suite("PollingBehavior.passesAlways")
    struct PassesAlwaysBehavior {
      // use a very generous delta for CI reasons.
      let delta = Duration.seconds(6)

      @Test("Simple passing expressions") func trivialHappyPath() async {
        let duration = await Test.Clock().measure {
          await #expect(until: .passesAlways) { true }
        }
        #expect(duration.isCloseTo(other: .seconds(60), within: delta))
      }

      @Test("Simple failing expressions") func trivialSadPath() async {
        let duration = await Test.Clock().measure {
          await confirmation("Polling failed", expectedCount: 1) { failed in
            var configuration = Configuration()
            configuration.eventHandler = { event, _ in
              if case .issueRecorded = event.kind {
                failed()
              }
            }
            await Test {
              await #expect(until: .passesAlways) { false }
            }.run(configuration: configuration)
          }
        }
        #expect(duration.isCloseTo(other: .zero, within: delta))
      }

      @Test("if the closures starts off as false, but would become true")
      func changingFromFail() async {
        let incrementor = Incrementor()

        let duration = await Test.Clock().measure {
          await confirmation("Polling failed", expectedCount: 1) { failed in
            var configuration = Configuration()
            configuration.eventHandler = { event, _ in
              if case .issueRecorded = event.kind {
                failed()
              }
            }
            await Test {
              await #expect(until: .passesAlways) {
                await incrementor.increment() == 2
              }
              // this will pass only on the second invocation
              // This checks that we fail the test if it immediately returns false
            }.run(configuration: configuration)
          }
        }

        #expect(await incrementor.count == 1)
        #expect(duration.isCloseTo(other: .zero, within: delta))
      }

      @Test("if the closure continues to pass")
      func continuousCalling() async {
        let incrementor = Incrementor()

        let duration = await Test.Clock().measure {
          await #expect(until: .passesAlways) {
            _ = await incrementor.increment()
            return true
          }
        }

        #expect(await incrementor.count > 1)
        #expect(duration.isCloseTo(other: .seconds(60), within: delta))
      }

      @Test("Unexpected Errors will automatically exit & fail") func errorsReported() async {
        let duration = await Test.Clock().measure {
          await confirmation("Polling failed", expectedCount: 1) { failed in
            var configuration = Configuration()
            configuration.eventHandler = { event, _ in
              if case .issueRecorded = event.kind {
                failed()
              }
            }
            await Test {
              await #expect(until: .passesOnce) {
                throw PollingTestSampleError.ohNo
              }
            }.run(configuration: configuration)
          }
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

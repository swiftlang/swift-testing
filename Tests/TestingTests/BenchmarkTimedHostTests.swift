//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

/// A clock whose current instant is set by the test rather than by the system.
private struct FakeClock: Clock {
  final class State: @unchecked Sendable {
    var now: Duration = .zero
  }

  struct Instant: InstantProtocol {
    var offset: Duration

    func advanced(by duration: Duration) -> Self {
      Self(offset: offset + duration)
    }

    func duration(to other: Self) -> Duration {
      other.offset - offset
    }

    static func <(lhs: Self, rhs: Self) -> Bool {
      lhs.offset < rhs.offset
    }
  }

  var state: State

  var now: Instant {
    Instant(offset: state.now)
  }

  var minimumResolution: Duration {
    .zero
  }

  func sleep(until deadline: Instant, tolerance: Duration?) async throws {}
}

/// Spin for a fixed amount of arithmetic work.
private func spin(_ units: Int) {
  var total = 0
  for i in 0..<(units * 50_000) {
    total &+= i
  }
  _ = total
}

@Suite("Benchmark.TimedHost")
struct TimedHostTests {
  static func measure(
    iterations: Int = 20,
    warmup: Int = 2,
    scale: Int? = nil,
    _ body: @escaping @Sendable (any Benchmark.Context) throws -> Void
  ) throws -> Benchmark.Results {
    var configuration = Benchmark.Configuration(displayName: "test")
    configuration.maximumIterationCount = iterations
    configuration.warmupIterationCount = warmup
    configuration.innerIterationCount = scale
    return try Benchmark.TimedHost().run(Benchmark.Body(body), configuration: configuration)
  }

  @Test func `A body that never calls startMeasurement is measured in its entirety`() throws {
    let results = try Self.measure { _ in spin(1) }
    let measurement = try #require(results[.wallClockTime])
    #expect(measurement.sampleCount == 20)
    #expect(measurement.minimum > 0)
  }

  @Test func `Restarting the clock discards the time already measured`() {
    let state = FakeClock.State()
    var clock = Benchmark.TimedHost.InterruptibleClock(clock: FakeClock(state: state))

    state.now = .seconds(1)
    clock.start()
    state.now = .seconds(3)
    clock.stop()
    #expect(clock.measuredDuration == .seconds(2))

    // A second interval must replace the first, not accumulate onto it.
    state.now = .seconds(10)
    clock.start()
    state.now = .seconds(11)
    clock.stop()
    #expect(clock.measuredDuration == .seconds(1))
  }

  @Test func `Stopping an already-stopped clock does nothing`() {
    let state = FakeClock.State()
    var clock = Benchmark.TimedHost.InterruptibleClock(clock: FakeClock(state: state))

    state.now = .seconds(1)
    clock.start()
    state.now = .seconds(2)
    clock.stop()
    state.now = .seconds(100)
    clock.stop()
    #expect(clock.measuredDuration == .seconds(1))
  }

  @Test func `A clock that is never stopped measures nothing`() {
    let state = FakeClock.State()
    var clock = Benchmark.TimedHost.InterruptibleClock(clock: FakeClock(state: state))
    clock.start()
    state.now = .seconds(5)
    #expect(clock.measuredDuration == .zero)
  }

  @Test func `Work before startMeasurement is excluded`() throws {
    let unbracketed = try Self.measure { _ in spin(10) }
    let bracketed = try Self.measure { _ in
      spin(9)
      Benchmark.measure {
        spin(1)
      }
    }
    let all = try #require(unbracketed[.wallClockTime])
    let some = try #require(bracketed[.wallClockTime])
    #expect(some.median < all.median / 2)
  }

  @Test func `Work after stopMeasurement is excluded`() throws {
    let results = try Self.measure { context in
      spin(1)
      context.stopMeasurement()
      spin(9)
    }
    let unbracketed = try Self.measure { _ in spin(10) }
    let some = try #require(results[.wallClockTime])
    let all = try #require(unbracketed[.wallClockTime])
    #expect(some.median < all.median / 2)
  }

  @Test func `Iteration counts are reported back`() throws {
    let results = try Self.measure(iterations: 7, warmup: 3, scale: 500) { _ in spin(1) }
    #expect(results.iterationCount == 7)
    #expect(results.warmupIterationCount == 3)
    #expect(results.innerIterationCount == 500)
    #expect(try #require(results[.wallClockTime]).sampleCount == 7)
  }

  @Test func `The current context is available to a running benchmark`() throws {
    nonisolated(unsafe) var seen: Int?
    _ = try Self.measure(iterations: 1, warmup: 0, scale: 42) { _ in
      seen = Benchmark.currentContext?.innerIterationCount
    }
    #expect(seen == 42)
  }

  @Test func `The current context is nil outside a benchmark`() {
    #expect(Benchmark.currentContext == nil)
    // Benchmark.measure is a no-op outside a benchmark rather than a trap.
    #expect(Benchmark.measure { 7 } == 7)
  }

  @Test func `No benchmark host is linked into the testing library own tests`() throws {
    #expect(Benchmark.HostRegistration.allHostsInProcess.isEmpty)
  }
}

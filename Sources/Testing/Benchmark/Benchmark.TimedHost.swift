//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Benchmark {
  /// A benchmark host that measures elapsed wall clock time.
  ///
  /// This host is used when no other benchmark host is linked into a test target.
  /// It is deliberately not discoverable as test content, so that linking a host
  /// always takes precedence over it without needing to be disambiguated from it.
  struct TimedHost: Benchmark.Host {
    /// The number of warmup iterations to perform when a benchmark does not specify
    /// a count.
    private static var defaultWarmupIterationCount: Int { 10 }

    /// The number of measured iterations to perform when a benchmark does not
    /// specify a count.
    private static var defaultIterationCount: Int { 100 }

    /// The amount of time to spend on a benchmark when it does not specify a
    /// budget, in nanoseconds.
    private static var defaultTimeBudgetNanoseconds: Int64 { 1_000_000_000 }

    /// A clock that measures the total time spanned by one or more intervals.
    struct InterruptibleClock<ClockType: Clock> {
      var clock: ClockType

      /// Initialize an instance of this type.
      ///
      /// - Parameters:
      ///   - clock: The clock to read the current instant from.
      init(clock: ClockType) {
        self.clock = clock
      }

      /// The instant measurement began, or `nil` if measurement is not in progress.
      private var startTime: ClockType.Instant?

      /// The measured time.
      private(set) var measuredDuration: ClockType.Duration = .zero

      /// Begin measuring, discarding any time already measured.
      ///
      /// Starting an already-running clock is not an error: a benchmark that
      /// performs setup work starts measuring once that work is complete, and the
      /// time leading up to that point is deliberately discarded.
      mutating func start() {
        measuredDuration = .zero
        startTime = clock.now
      }

      /// Stop measuring, adding the time since the last call to ``start()`` to
      /// ``measuredDuration``.
      ///
      /// Stopping an already-stopped clock does nothing.
      mutating func stop() {
        guard let startTime else {
          return
        }
        measuredDuration += startTime.duration(to: clock.now)
        self.startTime = nil
      }
    }

    /// The context passed to a benchmark's body.
    final class Context: Benchmark.Context {
      var clock = InterruptibleClock<Test.Clock>(clock: .init())
      let innerIterationCount: Int

      init(innerIterationCount: Int) {
        self.innerIterationCount = innerIterationCount
      }

      func startMeasurement() {
        clock.start()
      }

      func stopMeasurement() {
        clock.stop()
      }
    }

    var identifier: String { "com.apple.Testing.TimedHost" }

    func run(
      _ body: Benchmark.Body,
      configuration: Benchmark.Configuration
    ) throws -> Benchmark.Results {
      let innerIterationCount = configuration.innerIterationCount ?? 1
      let warmupIterationCount = configuration.warmupIterationCount ?? Self.defaultWarmupIterationCount
      let iterationCount = configuration.maximumIterationCount ?? Self.defaultIterationCount

      let context = Context(innerIterationCount: innerIterationCount)

      // Stop early once the budget is spent, so that a slow benchmark does not
      // take iterationCount times as long as one invocation. At least one
      // measured iteration is always performed.
      let clock = Test.Clock()
      let budget = configuration.timeBudgetNanoseconds ?? Self.defaultTimeBudgetNanoseconds
      let deadline = clock.now.advanced(by: .nanoseconds(budget))

      var warmupCount = 0
      for _ in 0..<warmupIterationCount {
        try body(context)
        warmupCount += 1
        if clock.now >= deadline {
          break
        }
      }

      var durations = [Duration]()
      durations.reserveCapacity(iterationCount)
      for iteration in 0..<iterationCount {
        if iteration > 0 && clock.now >= deadline {
          break
        }
        // Bracket each invocation so that a benchmark which never starts measuring
        // is measured in its entirety, and one which never stops measuring is
        // measured until it returns.
        context.clock.start()
        try body(context)
        context.clock.stop()

        durations.append(context.clock.measuredDuration)
      }

      let measurement = Benchmark.Measurement(
        metric: .wallClockTime,
        summarizing: durations.map(\.nanoseconds)
      )

      return Benchmark.Results(
        measurements: measurement.map { [$0] } ?? [],
        iterationCount: durations.count,
        warmupIterationCount: warmupCount,
        innerIterationCount: innerIterationCount
      )
    }
  }
}

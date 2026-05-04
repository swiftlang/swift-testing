//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Benchmark.Trait where Self: TestScoping {
  /// Modify the benchmark settings in the current configuration for the duration
  /// of a benchmark.
  ///
  /// - Parameters:
  ///   - function: The function to perform with the modified configuration.
  ///   - transform: A closure that modifies the benchmark settings.
  ///
  /// - Throws: Whatever `function` throws.
  fileprivate func withBenchmarkConfiguration(
    performing function: () async throws -> Void,
    modifiedBy transform: (inout Benchmark.Configuration) -> Void
  ) async throws {
    var configuration = Configuration.current ?? .init()
    transform(&configuration.benchmarkConfiguration)
    try await Configuration.withCurrent(configuration) {
      try await function()
    }
  }
}

// MARK: - Warmup

/// A type that specifies how many warmup iterations a benchmark performs.
///
/// To add this trait to a benchmark, use ``Trait/warmup(_:)``.
extension Benchmark {
  public struct Warmup: Benchmark.Trait, TestScoping {
    /// The number of warmup iterations to perform.
    public var iterationCount: Int

    public func provideScope(
      for test: Test,
      testCase: Test.Case?,
      performing function: () async throws -> Void
    ) async throws {
      try await withBenchmarkConfiguration(performing: function) { configuration in
        configuration.warmupIterationCount = iterationCount
      }
    }
  }
}

extension Trait where Self == Benchmark.Warmup {
  /// Specify the number of warmup iterations a benchmark performs before it is
  /// measured.
  ///
  /// - Parameters:
  ///   - iterationCount: The number of warmup iterations to perform.
  ///
  /// - Returns: An instance of ``Benchmark/Warmup``.
  ///
  /// Warmup iterations are not measured. They give caches, branch predictors, and
  /// lazily-initialized state a chance to reach a steady state so that the first
  /// measured iteration is not an outlier.
  ///
  /// If a benchmark does not have this trait, its host chooses how many warmup
  /// iterations to perform.
  public static func warmup(_ iterationCount: Int) -> Self {
    Self(iterationCount: iterationCount)
  }
}

// MARK: - Scale

/// A type that specifies how many times a benchmark repeats its work within a
/// single measured iteration.
///
/// To add this trait to a benchmark, use ``Trait/scale(_:)``.
extension Benchmark {
  public struct Scale: Benchmark.Trait, TestScoping {
    /// The number of iterations to perform within a single measured iteration.
    public var iterationCount: Int

    public func provideScope(
      for test: Test,
      testCase: Test.Case?,
      performing function: () async throws -> Void
    ) async throws {
      try await withBenchmarkConfiguration(performing: function) { configuration in
        configuration.innerIterationCount = iterationCount
      }
    }
  }
}

extension Trait where Self == Benchmark.Scale {
  /// Specify how many times a benchmark repeats its work within a single measured
  /// iteration.
  ///
  /// - Parameters:
  ///   - iterationCount: The number of iterations to perform within a single
  ///     measured iteration.
  ///
  /// - Returns: An instance of ``Benchmark/Scale``.
  ///
  /// An operation faster than the host's clock resolution cannot be measured on
  /// its own. Use this trait to repeat the operation enough times that the cost of
  /// taking a measurement is amortized across many iterations; the host divides
  /// the result back down to a per-iteration figure.
  ///
  /// A benchmark with this trait must perform the requested number of iterations
  /// itself, using the count its host supplies:
  ///
  /// ```swift
  /// @Benchmark(.scale(1_000))
  /// func sorting(_ benchmark: Benchmark/Context) {
  ///   for _ in 0 ..< benchmark.innerIterationCount {
  ///     // ...
  ///   }
  /// }
  /// ```
  public static func scale(_ iterationCount: Int) -> Self {
    Self(iterationCount: iterationCount)
  }
}

// MARK: - Metrics

/// A type that specifies which metrics a benchmark asks its host to measure.
///
/// To add this trait to a benchmark, use ``Trait/metrics(_:)``.
extension Benchmark {
  public struct Metrics: Benchmark.Trait, TestScoping {
    /// The metrics to measure.
    public var metrics: [Benchmark.Metric]

    public func provideScope(
      for test: Test,
      testCase: Test.Case?,
      performing function: () async throws -> Void
    ) async throws {
      try await withBenchmarkConfiguration(performing: function) { configuration in
        configuration.requestedMetrics = metrics
      }
    }
  }
}

extension Trait where Self == Benchmark.Metrics {
  /// Specify which metrics a benchmark asks its host to measure.
  ///
  /// - Parameters:
  ///   - metrics: The metrics to measure.
  ///
  /// - Returns: An instance of ``Benchmark/Metrics``.
  ///
  /// Which metrics are available depends on the benchmark host in use. A host that
  /// cannot measure a requested metric reports it in
  /// ``Benchmark/Results/unavailableMetrics`` rather than failing the benchmark.
  ///
  /// If a benchmark does not have this trait, its host measures whatever it
  /// measures by default.
  public static func metrics(_ metrics: Benchmark.Metric...) -> Self {
    Self(metrics: metrics)
  }
}

// MARK: - Deriving a configuration

extension Benchmark.Configuration {
  /// Initialize an instance of this type describing a benchmark that is about to
  /// run.
  ///
  /// - Parameters:
  ///   - test: The benchmark being run.
  ///   - testCase: The test case of `test` being run, if any.
  ///   - displayName: A human-readable name for the benchmark.
  ///
  /// Call this initializer from within the scope provided by `test`'s traits so
  /// that settings those traits applied are reflected in the result.
  init(for test: Test, testCase: Test.Case?, displayName: String) {
    let configuration = Configuration.current ?? .init()
    self = configuration.benchmarkConfiguration
    self.displayName = displayName

    // A benchmark's time limit is its measurement budget: unlike a test, a
    // benchmark is not timed out, so the limit is advisory and it is the host that
    // decides to stop.
    if let timeLimit = test.adjustedTimeLimit(configuration: configuration) {
      let (seconds, attoseconds) = timeLimit.components
      let nanoseconds = (seconds * 1_000_000_000) + (attoseconds / 1_000_000_000)
      timeBudgetNanoseconds = timeBudgetNanoseconds.map { min($0, nanoseconds) } ?? nanoseconds
    }

    if let arguments = testCase?.arguments {
      tags = Dictionary(
        arguments.lazy.map { argument in
          let parameter = argument.parameter
          return (parameter.secondName ?? parameter.firstName, String(describingForTest: argument.value))
        },
        uniquingKeysWith: { _, last in last }
      )
    }
  }
}

//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// The settings under which a host should run one benchmark.
///
/// The testing library derives an instance of this type from the traits applied to
/// a benchmark. Properties whose value is `nil` were not specified, and the host
/// should substitute its own default.
///
/// A host that wants to expose settings only it understands should declare its own
/// ``Benchmark/Trait`` and carry the setting however it likes; this type covers only
/// the settings every host has in common.
extension Benchmark {
  public struct Configuration: Sendable {
    /// A human-readable name for the benchmark being run.
    ///
    /// The testing library sets this property when it runs a benchmark. A trait that
    /// modifies the current configuration should leave it alone.
    public var displayName: String = ""

    /// The metrics the benchmark asked the host to measure.
    ///
    /// If this array is empty, the host should measure whatever it measures by
    /// default. A host that cannot measure a requested metric should report it in
    /// ``Benchmark/Results/unavailableMetrics`` rather than failing.
    public var requestedMetrics: [Benchmark.Metric]

    /// The number of warmup iterations to perform before measuring.
    public var warmupIterationCount: Int?

    /// The number of iterations the benchmark's body should perform internally
    /// during each measured iteration.
    ///
    /// Hosts pass this value to the body as
    /// ``Benchmark/Context/innerIterationCount``. Amortizing measurement overhead
    /// across many inner iterations is how a host measures an operation faster than
    /// its clock's resolution.
    public var innerIterationCount: Int?

    /// The maximum number of measured iterations to perform.
    public var maximumIterationCount: Int?

    /// The maximum amount of time to spend measuring, in nanoseconds.
    ///
    /// The testing library derives this value from the time limit that applies to
    /// the benchmark, as set by ``Trait/timeLimit(_:)-4kzjp`` or
    /// ``Configuration/defaultTestTimeLimit``. If no time limit applies, the value
    /// of this property is `nil` and the host chooses for itself.
    ///
    /// Unlike a test, a benchmark is never timed out: a single iteration that runs
    /// longer than this value is not a failure. The budget bounds how long a host
    /// keeps iterating, not how long one iteration may take.
    public var timeBudgetNanoseconds: Int64?

    /// Key-value pairs describing the parameters of this benchmark, such as the
    /// arguments of a parameterized benchmark.
    public var tags: [String: String]

    /// Initialize an instance of this type.
    public init(
      displayName: String = "",
      requestedMetrics: [Benchmark.Metric] = [],
      warmupIterationCount: Int? = nil,
      innerIterationCount: Int? = nil,
      maximumIterationCount: Int? = nil,
      timeBudgetNanoseconds: Int64? = nil,
      tags: [String: String] = [:]
    ) {
      self.displayName = displayName
      self.requestedMetrics = requestedMetrics
      self.warmupIterationCount = warmupIterationCount
      self.innerIterationCount = innerIterationCount
      self.maximumIterationCount = maximumIterationCount
      self.timeBudgetNanoseconds = timeBudgetNanoseconds
      self.tags = tags
    }
  }
}

#if !SWT_NO_CODABLE
// MARK: - Codable

extension Benchmark.Configuration: Codable {}
#endif

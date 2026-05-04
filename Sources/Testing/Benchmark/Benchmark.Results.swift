//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A summary of one metric measured while running a benchmark.
///
/// Values are expressed in the canonical unit of ``metric``. Hosts summarize their
/// own samples: the testing library does not accept raw sample values, both because
/// a host that accumulates into a histogram cannot produce them and because
/// computing statistics is the part of benchmarking where hosts differ most.
extension Benchmark {
  public struct Measurement: Sendable {
    /// The metric that was measured.
    public var metric: Benchmark.Metric

    /// The number of samples this measurement summarizes.
    public var sampleCount: Int

    /// The smallest sampled value.
    public var minimum: Int64

    /// The 50th percentile of the sampled values.
    public var median: Int64

    /// The 90th percentile of the sampled values.
    public var p90: Int64

    /// The 99th percentile of the sampled values.
    public var p99: Int64

    /// The largest sampled value.
    public var maximum: Int64

    /// The arithmetic mean of the sampled values.
    public var mean: Double

    /// The standard deviation of the sampled values, if the host computed one.
    public var standardDeviation: Double?

    /// Initialize an instance of this type.
    public init(
      metric: Benchmark.Metric,
      sampleCount: Int,
      minimum: Int64,
      median: Int64,
      p90: Int64,
      p99: Int64,
      maximum: Int64,
      mean: Double,
      standardDeviation: Double? = nil
    ) {
      self.metric = metric
      self.sampleCount = sampleCount
      self.minimum = minimum
      self.median = median
      self.p90 = p90
      self.p99 = p99
      self.maximum = maximum
      self.mean = mean
      self.standardDeviation = standardDeviation
    }

    /// Initialize an instance of this type by summarizing a set of samples.
    ///
    /// - Parameters:
    ///   - metric: The metric that was measured.
    ///   - values: The sampled values, in `metric`'s canonical unit. Need not be
    ///     sorted.
    ///
    /// If `values` is empty, the result is `nil`.
    ///
    /// This initializer is a convenience for hosts that retain every sample. A host
    /// that accumulates into a histogram should use
    /// ``init(metric:sampleCount:minimum:median:p90:p99:maximum:mean:standardDeviation:)``
    /// instead.
    public init?(metric: Benchmark.Metric, summarizing values: some Collection<Int64>) {
      guard !values.isEmpty else {
        return nil
      }
      let sorted = values.sorted()
      let total = sorted.reduce(Int64(0), &+)
      let mean = Double(total) / Double(sorted.count)
      let variance = sorted.reduce(0.0) { partial, value in
        let delta = Double(value) - mean
        return partial + (delta * delta)
      } / Double(sorted.count)

      func percentile(_ percentile: Double) -> Int64 {
        let offset = (percentile / 100.0) * Double(sorted.count - 1)
        return sorted[Int(offset.rounded())]
      }

      self.init(
        metric: metric,
        sampleCount: sorted.count,
        minimum: sorted[0],
        median: percentile(50),
        p90: percentile(90),
        p99: percentile(99),
        maximum: sorted[sorted.count - 1],
        mean: mean,
        standardDeviation: variance.squareRoot()
      )
    }
  }
}

// MARK: -

/// The outcome of running one benchmark on a host.
extension Benchmark {
  public struct Results: Sendable {
    /// What the host measured, one element per metric.
    public var measurements: [Benchmark.Measurement]

    /// The number of measured iterations the host performed, excluding warmup.
    public var iterationCount: Int

    /// The number of warmup iterations the host performed.
    public var warmupIterationCount: Int

    /// The number of iterations the benchmark's body performed internally during
    /// each measured iteration.
    ///
    /// The value of this property equals the value the host supplied as
    /// ``Benchmark/Context/innerIterationCount``.
    public var innerIterationCount: Int

    /// Metrics that were requested but which the host did not produce, and the
    /// reason for each.
    ///
    /// Reporting an unproduced metric here lets tools distinguish "measured zero"
    /// from "not measured", and lets the testing library diagnose a request that
    /// silently went unfulfilled.
    public var unavailableMetrics: [Benchmark.Metric: String]

    /// Host-defined key-value pairs describing this run, such as the name of the
    /// allocator backend in use.
    public var tags: [String: String]

    /// Initialize an instance of this type.
    public init(
      measurements: [Benchmark.Measurement],
      iterationCount: Int,
      warmupIterationCount: Int = 0,
      innerIterationCount: Int = 1,
      unavailableMetrics: [Benchmark.Metric: String] = [:],
      tags: [String: String] = [:]
    ) {
      self.measurements = measurements
      self.iterationCount = iterationCount
      self.warmupIterationCount = warmupIterationCount
      self.innerIterationCount = innerIterationCount
      self.unavailableMetrics = unavailableMetrics
      self.tags = tags
    }

    /// Get the measurement for a given metric.
    ///
    /// - Parameters:
    ///   - metric: The metric of interest.
    ///
    /// - Returns: The corresponding measurement, or `nil` if the host did not
    ///   produce one.
    public subscript(metric: Benchmark.Metric) -> Benchmark.Measurement? {
      measurements.first { $0.metric == metric }
    }
  }
}

#if !SWT_NO_CODABLE
// MARK: - Codable

extension Benchmark.Measurement: Codable {}
extension Benchmark.Results: Codable {}
#endif

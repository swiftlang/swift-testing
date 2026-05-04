//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A quantity that a benchmark host can measure.
///
/// A metric's ``identifier`` establishes its identity: two metrics with equal
/// identifiers are the same metric even if their other properties differ.
/// Identifiers are host-scoped, so a metric produced by one host is not
/// guaranteed to be semantically comparable to a metric with the same identifier
/// produced by another host.
///
/// Hosts define their own metrics. The testing library deliberately does not
/// enumerate a set of well-known metrics beyond ``wallClockTime``: the meaning of
/// a measurement such as "number of allocations" depends on how a particular host
/// counts, and a shared vocabulary would imply a guarantee no host can make on
/// another host's behalf.
extension Benchmark {
  public struct Metric: Sendable {
    /// A stable, machine-readable identifier for this metric.
    ///
    /// Use reverse-DNS notation (for example, `"com.example.gpu-cycles"`) for
    /// host-defined metrics so that identifiers do not collide between hosts.
    public var identifier: String

    /// A human-readable name for this metric, suitable for presentation.
    public var displayName: String

    /// The unit in which values of this metric are expressed.
    public var unit: Unit

    /// Whether larger or smaller values of this metric indicate better performance.
    public var polarity: Polarity

    /// Whether the magnitude of this metric is proportional to the number of
    /// iterations performed within a single invocation of a benchmark's body.
    public var scalesWithIterationCount: Bool

    /// Initialize an instance of this type.
    ///
    /// - Parameters:
    ///   - identifier: A stable, machine-readable identifier for the metric.
    ///   - displayName: A human-readable name for the metric. If `nil`,
    ///     `identifier` is used.
    ///   - unit: The unit in which values of the metric are expressed.
    ///   - polarity: Whether larger or smaller values indicate better performance.
    ///   - scalesWithIterationCount: Whether the metric's magnitude is proportional
    ///     to the number of inner iterations performed.
    public init(
      identifier: String,
      displayName: String? = nil,
      unit: Unit,
      polarity: Polarity = .prefersSmaller,
      scalesWithIterationCount: Bool = true
    ) {
      self.identifier = identifier
      self.displayName = displayName ?? identifier
      self.unit = unit
      self.polarity = polarity
      self.scalesWithIterationCount = scalesWithIterationCount
    }
  }
}

// MARK: - Unit and polarity

extension Benchmark.Metric {
  /// A unit in which a metric's values are expressed.
  ///
  /// Values are always stored in the canonical unit described by each case.
  /// Choosing a magnitude prefix suitable for presentation (for example, showing
  /// 1,500,000 nanoseconds as "1.5 ms") is the responsibility of whatever presents
  /// the measurement, not of the host that produced it.
  public enum Unit: Sendable, Hashable {
    /// A duration, expressed in nanoseconds.
    case nanoseconds

    /// A dimensionless count.
    case count

    /// A quantity of memory or storage, expressed in bytes.
    case bytes

    /// A quantity expressed in some other unit.
    ///
    /// - Parameters:
    ///   - symbol: A short symbol for the unit, such as `"ops/s"`, suitable for
    ///     presentation alongside a value.
    case other(symbol: String)
  }

  /// Whether larger or smaller measurements indicate better performance.
  public enum Polarity: Sendable, Hashable {
    /// Smaller values indicate better performance.
    case prefersSmaller

    /// Larger values indicate better performance.
    case prefersLarger
  }
}

// MARK: - Well-known metrics

extension Benchmark.Metric {
  /// The elapsed wall clock time taken by a benchmark.
  ///
  /// This is the only metric the testing library defines. It exists because it is
  /// the one quantity every host can measure and because tools need at least one
  /// metric whose meaning is stable enough to compare across hosts.
  public static var wallClockTime: Self {
    Self(
      identifier: "wallClockTime",
      displayName: "Time (wall clock)",
      unit: .nanoseconds
    )
  }
}

// MARK: - Hashable, CustomStringConvertible

extension Benchmark.Metric: Hashable {
  /// Compare two metrics for equality.
  ///
  /// Metrics are equal if their identifiers are equal. The remaining properties
  /// are descriptive and are ignored, so that a metric requested by a test author
  /// matches the corresponding metric produced by a host even if the host
  /// describes it differently.
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.identifier == rhs.identifier
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }
}

extension Benchmark.Metric: CustomStringConvertible {
  public var description: String {
    displayName
  }
}

#if !SWT_NO_CODABLE
// MARK: - Codable

extension Benchmark.Metric: Codable {}
extension Benchmark.Metric.Unit: Codable {}
extension Benchmark.Metric.Polarity: Codable {}
#endif

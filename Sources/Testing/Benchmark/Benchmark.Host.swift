//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type that measures benchmarks on behalf of the testing library.
///
/// The testing library discovers benchmarks, applies their traits, and reports
/// their results; a host performs the measurement. Hosts are discovered at
/// runtime, so the testing library does not need to know about a host when it is
/// built. To make a host discoverable, apply the `@Benchmark.Host` macro to it, or
/// see ``Benchmark/HostRegistration`` to emit its record by hand.
///
/// If no host is linked into a test target, benchmarks are measured by a built-in
/// host that records elapsed wall clock time. Linking a host replaces it.
///
/// A host owns the entire measurement loop. The testing library does not iterate
/// on a host's behalf: it hands over a ``Benchmark/Body`` and a
/// ``Benchmark/Configuration``, and the host decides how many warmup and measured
/// iterations to perform, when to start and stop its counters, and when it has
/// gathered enough data.
extension Benchmark {
  public protocol Host: Sendable {
    /// Initialize an instance of this host.
    ///
    /// The testing library instantiates a host from a C function pointer that takes
    /// no arguments, so a host must be default-initializable. A host that needs
    /// shared state can hold a reference to it rather than owning it.
    init()

    /// A stable, machine-readable identifier for this host.
    ///
    /// Use reverse-DNS notation, for example `"one.ordo.benchmark"`. Tools use this
    /// value to select a host when more than one is present.
    var identifier: String { get }

    /// A human-readable name for this host, suitable for presentation.
    ///
    /// The default value of this property is ``identifier``.
    var displayName: String { get }

    /// Measure one benchmark.
    ///
    /// - Parameters:
    ///   - body: The work to measure. Invoke this value as many times as needed.
    ///   - configuration: The settings to measure under. Substitute this host's own
    ///     defaults for any property whose value is `nil`.
    ///
    /// - Returns: What this host measured.
    ///
    /// - Throws: Any error preventing this benchmark from being measured. The
    ///   testing library records such an error as a failure of the corresponding
    ///   benchmark and continues with the next one.
    ///
    /// This function is synchronous, and the testing library calls it on the main
    /// actor. A benchmark therefore occupies one known thread for its whole
    /// duration rather than hopping between threads of the cooperative pool, which
    /// a thread-affine counter could not tolerate.
    ///
    /// The testing library runs benchmarks after every test has finished, one at a
    /// time, so nothing else in the process runs concurrently with this function. A
    /// host may rely on that when reading process-wide counters such as allocation
    /// counts.
    func run(
      _ body: Benchmark.Body,
      configuration: Benchmark.Configuration
    ) throws -> Benchmark.Results
  }
}

// MARK: - Default implementations

extension Benchmark.Host {
  public var displayName: String {
    identifier
  }
}

// MARK: - Errors

/// An error involving a benchmark host.
extension Benchmark {
  public enum HostError: Error {
    /// More than one benchmark host was discovered and none was selected.
    ///
    /// - Parameters:
    ///   - identifiers: The identifiers of the hosts that were discovered.
    case multipleHostsAvailable(identifiers: [String])

    /// The host selected by identifier was not discovered in this process.
    ///
    /// - Parameters:
    ///   - identifier: The identifier that was requested.
    case hostNotFound(identifier: String)

    /// The host could not measure the benchmark.
    ///
    /// - Parameters:
    ///   - reason: A human-readable explanation.
    case measurementFailed(reason: String)
  }
}

extension Benchmark.HostError: CustomStringConvertible {
  public var description: String {
    switch self {
    case let .multipleHostsAvailable(identifiers):
      "More than one benchmark host is available (\(identifiers.sorted().joined(separator: ", "))). Select one by identifier."
    case let .hostNotFound(identifier):
      "No benchmark host with the identifier '\(identifier)' is available."
    case let .measurementFailed(reason):
      reason
    }
  }
}

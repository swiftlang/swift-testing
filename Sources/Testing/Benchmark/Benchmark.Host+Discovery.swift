//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) @_spi(ForToolsIntegrationOnly) private import _TestDiscovery

/// How a benchmark host makes itself discoverable by the testing library.
///
/// A host emits a test content record of kind ``kind`` into the test content
/// section of the test binary. The testing library walks that section at runtime,
/// so a host is discovered without the testing library having any build-time
/// knowledge of it.
///
/// A host emits a record by declaring a constant of type
/// ``Benchmark/HostRecordLayout`` in the appropriate section:
///
/// ```swift
/// @used
/// #if objectFormat(MachO)
/// @section("__DATA_CONST,__swift5_tests")
/// #elseif objectFormat(ELF) || objectFormat(Wasm)
/// @section("swift5_tests")
/// #elseif objectFormat(COFF)
/// @section(".sw5test$B")
/// #endif
/// private let benchmarkHostRecord: Benchmark/HostRecordLayout = (
///   0x62656e63, /* 'benc' */
///   0,
///   { outValue, type, _, _ in
///     Benchmark.HostRegistration.store(MyHost(), into: outValue, asTypeAt: type)
///   },
///   1, // Benchmark.HostRegistration.currentABIVersion
///   0
/// )
/// ```
///
/// - Note: A global variable placed in a section must be initialized by a literal
///   expression, so the `kind` and `context` fields cannot be written as references
///   to ``kind`` and ``currentABIVersion``.
///
/// For the layout and semantics of test content records in general, see
/// `Documentation/ABI/TestContent.md`.
extension Benchmark {
  public enum HostRegistration: Sendable {
    /// The `kind` field of a benchmark host test content record.
    ///
    /// The value of this property is `0x62656e63`, or `'benc'` as a
    /// [FourCC](https://en.wikipedia.org/wiki/FourCC) value.
    public static var kind: UInt32 {
      0x62656e63
    }

    /// The current version of the benchmark host interface.
    ///
    /// A host stores this value in the `context` field of its record. The testing
    /// library reads that field before calling the record's accessor and ignores
    /// records whose version it does not recognize, so an incompatible host is
    /// rejected without its code being invoked.
    public static var currentABIVersion: UInt16 {
      1
    }

    /// Store a host into the memory a test content record accessor was given.
    ///
    /// - Parameters:
    ///   - host: The host to store. This value is only created if the accessor's
    ///     expected type matches.
    ///   - outValue: The uninitialized memory to store `host` into.
    ///   - typeAddress: A pointer to the expected type of the value to be stored, as
    ///     passed to the accessor.
    ///
    /// - Returns: Whether or not a value was stored into `outValue`.
    ///
    /// Comparing the expected type is what prevents memory corruption when two
    /// copies of the testing library are loaded into the same process. A host must
    /// propagate this function's return value out of its accessor unchanged.
    public static func store(
      _ host: @autoclosure () -> any Benchmark.Host,
      into outValue: UnsafeMutableRawPointer,
      asTypeAt typeAddress: UnsafeRawPointer
    ) -> CBool {
      Benchmark.HostRecord.store(host(), into: outValue, asTypeAt: typeAddress)
    }
  }
}

extension Benchmark {
  /// The type of the accessor function of a benchmark host test content record.
  public typealias HostRecordAccessor = @convention(c) (
    _ outValue: UnsafeMutableRawPointer,
    _ type: UnsafeRawPointer,
    _ hint: UnsafeRawPointer?,
    _ reserved: UInt
  ) -> CBool
}

/// The layout of a benchmark host test content record.
///
/// A host declares a constant of this type, in the test content section, to make
/// itself discoverable. See ``Benchmark/HostRegistration`` for an example.
extension Benchmark {
  public typealias HostRecordLayout = (
    kind: UInt32,
    reserved1: UInt32,
    accessor: HostRecordAccessor,
    context: UInt,
    reserved2: UInt
  )
}

// MARK: - Discovery

/// The value produced by a benchmark host's test content record.
///
/// This type is not part of the public interface: a host stores a value of this
/// type by calling ``Benchmark/HostRegistration/store(_:into:asTypeAt:)`` rather
/// than by naming it. Its identity is nonetheless what the accessor's type check
/// compares, so two copies of the testing library in one process reject each
/// other's records instead of misreading them.
extension Benchmark {
  fileprivate struct HostRecord: Sendable, DiscoverableAsTestContent {
    var host: any Benchmark.Host

    static var testContentKind: TestContentKind {
      .benchmarkHost
    }

    static func store(
      _ host: any Benchmark.Host,
      into outValue: UnsafeMutableRawPointer,
      asTypeAt typeAddress: UnsafeRawPointer
    ) -> CBool {
  #if !hasFeature(Embedded)
      guard typeAddress.load(as: Any.Type.self) == Self.self else {
        return false
      }
  #endif
      outValue.initializeMemory(as: Self.self, to: Self(host: host))
      return true
    }

    static var allHostsInProcess: [any Benchmark.Host] {
      allTestContentRecords().lazy
        .filter { UInt16(truncatingIfNeeded: $0.context) <= Benchmark.HostRegistration.currentABIVersion }
        .compactMap { $0.load()?.host }
    }
  }
}

extension Benchmark.HostRegistration {
  /// All benchmark hosts in the current process, according to the runtime.
  ///
  /// The order of values in this array is unspecified. Records whose ABI version
  /// the testing library does not recognize are omitted, so that a host built
  /// against a newer testing library is ignored rather than misinterpreted.
  static var allHostsInProcess: [any Benchmark.Host] {
    Benchmark.HostRecord.allHostsInProcess
  }
}

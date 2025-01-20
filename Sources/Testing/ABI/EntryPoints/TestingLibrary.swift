//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if hasFeature(SymbolLinkageMarkers)
/// A type describing a testing library whose test content can be hosted by
/// Swift Testing.
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
@frozen public struct TestingLibrary: Sendable {
  /// The human-readable name of this testing library.
  public var displayName: String

  /// The version of this testing library.
  ///
  /// It is recommended that a testing library's version be specified as a
  /// [semantic version](https://semver.org), but it is not required.
  public var version: String

  /// The type of testing library entry point functions.
  ///
  /// - Parameters:
  ///   - configurationJSON: A buffer to memory representing the test
  ///     configuration and options. If `nil`, a new instance is synthesized
  ///     from the command-line arguments to the current process.
  ///   - recordHandler: A JSON record handler to which is passed a buffer to
  ///     memory representing each record as described in `ABI/JSON.md`.
  ///
  /// - Returns: Whether or not the test run finished successfully.
  ///
  /// - Throws: Any error that occurred prior to running tests. Errors that are
  ///   thrown while tests are running are handled by the testing library.
  public typealias EntryPoint = @convention(thin) @Sendable (
    _ configurationJSON: UnsafeRawBufferPointer,
    _ recordHandler: @escaping @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void
  ) async throws -> Bool

  /// The entry point function of this testing library.
  public var entryPoint: EntryPoint

  public init(displayName: String, version: String, entryPoint: @escaping EntryPoint) {
    self.displayName = displayName
    self.version = version
    self.entryPoint = entryPoint
  }
}

// MARK: - UnsafeDiscoverable

extension TestingLibrary: UnsafeDiscoverable {
  public static var discoverableKind: UInt32 {
    _testingLibraryRecordKind
  }
}

// MARK: -

/// The "kind" value for all testing library records.
private let _testingLibraryRecordKind: UInt32 = 0x746C6962

/// The accessor function of this testing library's (i.e. Swift Testing's) test
/// content record.
///
/// This accessor function is specific to Swift Testing, and so is not a member
/// of ``TestingLibrary``.
private let _accessor: @convention(c) (UnsafeMutableRawPointer, UnsafeRawPointer?) -> CBool = { outValue, _ in
  _ = outValue.initializeMemory(
    as: TestingLibrary.self,
    to: TestingLibrary(
      displayName: "Swift Testing",
      version: testingLibraryVersion,
      entryPoint: ABIv0.entryPoint
    )
  )
  return true
}

/// The test content record of this testing library (i.e. Swift Testing.)
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
@_section("__DATA_CONST,__swift5_tests")
#elseif os(Linux) || os(FreeBSD) || os(OpenBSD) || os(Android) || os(WASI)
@_section("swift5_tests")
#elseif os(Windows)
@_section(".sw5test$B")
#else
@__testing(warning: "Platform-specific implementation missing: test content section name unavailable")
#endif
@_used
private let _testingLibraryRecord: __TestContentRecord = (_testingLibraryRecordKind, 0, _accessor, 0, 0)
#endif

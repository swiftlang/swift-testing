//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_LEGACY_TEST_DISCOVERY
@_spi(Experimental) @_spi(ForToolsIntegrationOnly) internal import _TestDiscovery

/// The content of a test content record as defined in the Swift 6.2 toolchain.
///
/// The layout of this type must match that of the corresponding type in the
/// `_TestDiscovery` module. For more information, see `ABI/TestContent.md`.
///
/// - Warning: This type is used to implement the `@Test` macro. Do not use it
///   directly.
public typealias __TestContentRecord6_2 = (
  kind: UInt32,
  reserved1: UInt32,
  accessor: __TestContentRecordAccessor?,
  context: UInt,
  reserved2: UInt
)

/// A protocol describing a type that contains tests.
///
/// - Warning: This protocol is used to implement the `@Test` macro. Do not use
///   it directly.
@_alwaysEmitConformanceMetadata
public protocol __TestContentRecordContainer {
  /// The test content record associated with this container.
  ///
  /// - Warning: This property is used to implement the `@Test` macro. Do not
  ///   use it directly.
  nonisolated static var __testContentRecord: __TestContentRecord6_2 { get }
}

extension DiscoverableAsTestContent {
  /// Get all test content of this type known to Swift and found in the current
  /// process using the legacy discovery mechanism.
  ///
  /// - Returns: A sequence of instances of ``TestContentRecord``. Only test
  ///   content records matching this ``TestContent`` type's requirements are
  ///   included in the sequence.
  static func allTypeMetadataBasedTestContentRecords() -> some Sequence<TestContentRecord<Self>> {
    return allTypeMetadataBasedTestContentRecords { type, buffer in
      guard let type = type as? any __TestContentRecordContainer.Type else {
        return false
      }

      buffer.withMemoryRebound(to: __TestContentRecord6_2.self) { buffer in
        buffer.baseAddress!.initialize(to: type.__testContentRecord)
      }
      return true
    }
  }
}
#endif

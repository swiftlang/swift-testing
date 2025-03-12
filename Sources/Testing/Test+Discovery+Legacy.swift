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

/// A protocol base class describing a type that contains tests.
///
/// - Warning: This class is used to implement the `@Test` macro. Do not use it
///   directly.
@_alwaysEmitConformanceMetadata
public protocol __TestContentRecordContainer {
  /// The test content record associated with this container.
  ///
  /// - Warning: This property is used to implement the `@Test` macro. Do not
  ///   use it directly.
  nonisolated static var __testContentRecord: __TestContentRecord { get }
}

extension DiscoverableAsTestContent where Self: ~Copyable {
  /// Get all test content of this type known to Swift and found in the current
  /// process using the legacy discovery mechanism.
  ///
  /// - Returns: A sequence of instances of ``TestContentRecord``. Only test
  ///   content records matching this ``TestContent`` type's requirements are
  ///   included in the sequence.
  static func allTypeMetadataBasedTestContentRecords() -> AnySequence<TestContentRecord<Self>> {
    return allTypeMetadataBasedTestContentRecords { type, buffer in
      guard let type = type as? any __TestContentRecordContainer.Type else {
        return false
      }

      buffer.withMemoryRebound(to: __TestContentRecord.self) { buffer in
        buffer.baseAddress!.initialize(to: type.__testContentRecord)
      }
      return true
    }
  }
}
#endif

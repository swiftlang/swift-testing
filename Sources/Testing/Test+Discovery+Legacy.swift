//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) @_spi(ForToolsIntegrationOnly) internal import _TestDiscovery

#if !SWT_NO_LEGACY_TEST_DISCOVERY
/// An abstract base class describing a type that contains tests.
///
/// - Warning: This class is used to implement the `@Test` macro. Do not use it
///   directly.
open class __TestContentRecordContainer {
  /// The corresponding test content record.
  ///
  /// - Warning: This property is used to implement the `@Test` macro. Do not
  ///   use it directly.
  open nonisolated class var __testContentRecord: __TestContentRecord {
    fatalError("Unimplemented")
  }
}

@available(*, unavailable)
extension __TestContentRecordContainer: Sendable {}

// MARK: -

extension DiscoverableAsTestContent where Self: ~Copyable {
  /// Get all test content of this type known to Swift and found in the current
  /// process using the legacy discovery mechanism.
  ///
  /// - Returns: A sequence of instances of ``TestContentRecord``. Only test
  ///   content records matching this ``TestContent`` type's requirements are
  ///   included in the sequence.
  static func allTypeMetadataBasedTestContentRecords() -> AnySequence<TestContentRecord<Self>> {
    allTestContentRecords(inSubclassesOf: __TestContentRecordContainer.self) { `class`, outRecord in
      outRecord.withMemoryRebound(to: __TestContentRecord.self, capacity: 1) { outRecord in
        outRecord.initialize(to: `class`.__testContentRecord)
      }
      return true
    }
  }
}

#if SWT_TARGET_OS_APPLE
// MARK: - Xcode 16 compatibility

/// A protocol describing a type that contains tests.
///
/// This protocol is used by tests emitted by Xcode 16.
@_alwaysEmitConformanceMetadata
@usableFromInline protocol __TestContainer {
  /// The set of tests contained by this type.
  static var __tests: [Test] { get async }
}
#endif
#endif

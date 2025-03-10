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

/// A shadow declaration of `_TestDiscovery.TestContentRecordContainer` that
/// allows us to add public conformances to it without causing the
/// `_TestDiscovery` module to appear in `Testing.private.swiftinterface`.
///
/// This protocol is not part of the public interface of the testing library.
@_alwaysEmitConformanceMetadata
protocol TestContentRecordContainer: _TestDiscovery.TestContentRecordContainer {}

/// An abstract base class describing a type that contains tests.
///
/// - Warning: This class is used to implement the `@Test` macro. Do not use it
///   directly.
open class __TestContentRecordContainer: TestContentRecordContainer {
  /// The corresponding test content record.
  ///
  /// - Warning: This property is used to implement the `@Test` macro. Do not
  ///   use it directly.
  open nonisolated class var __testContentRecord: __TestContentRecord {
    (0, 0, nil, 0, 0)
  }

  static func storeTestContentRecord(to outTestContentRecord: UnsafeMutableRawPointer) -> Bool {
    outTestContentRecord.withMemoryRebound(to: __TestContentRecord.self, capacity: 1) { outTestContentRecord in
      outTestContentRecord.initialize(to: __testContentRecord)
      return true
    }
  }
}

@available(*, unavailable)
extension __TestContentRecordContainer: Sendable {}
#endif

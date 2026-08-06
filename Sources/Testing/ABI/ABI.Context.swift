//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_ABI_JSON_SCHEMA
#if SWT_NO_CODABLE
#error("Platform-specific misconfiguration: support for the ABI JSON schema requires support for 'Codable'")
#endif

extension ABI {
  /// A type representing persistent context used when handling an ABI or JSON
  /// event stream.
  ///
  /// You can use this type to simplify code that consumes the event stream.
  /// Create an instance of this type when you first start consuming the event
  /// stream, and pass that instance to ``ABI/EncodedTest/init(decoding:in:)``
  /// and ``ABI/EncodedEvent/init(decoding:in:)``.
  public struct Context: Sendable {
    /// Those tests memoized by this instance, keyed by encoded test ID.
    private var _testsByEncodedID = [String: Test]()

    public init() {}

    /// Memoize the given test so it can be looked up later by its encoded ID.
    ///
    /// - Parameters:
    ///   - test: The test to memoize.
    ///   - encodedTestID: The previously-encoded ID of `test`.
    mutating func setTest<V>(_ test: Test, identifiedBy encodedTestID: ABI.EncodedTest<V>.ID) {
      _testsByEncodedID[encodedTestID.stringValue] = test
    }

    /// Find a test previously passed to ``setTest(_:identifiedBy:)``.
    ///
    /// - Parameters:
    ///   - encodedTestID: The previously-encoded ID of `test`.
    ///
    /// - Returns: An instance of ``Test`` corresponding to `encodedTestID`, or
    ///   `nil` if none was previously passed to ``setTest(_:identifiedBy:)``.
    func test<V>(identifiedBy encodedTestID: ABI.EncodedTest<V>.ID) -> Test? {
      _testsByEncodedID[encodedTestID.stringValue]
    }
  }
}
#endif

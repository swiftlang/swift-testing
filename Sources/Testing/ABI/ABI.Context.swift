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

    /// A type describing the keys of the `_testCasesByEncodedID` property.
    private struct _TestCaseKey: Sendable, Equatable, Hashable {
      /// The string value of the corresponding test ID.
      var testID: String

      /// The string value of the corresponding test case ID.
      var testCaseID: String
    }

    /// Those test cases memoized by this instance, keyed by encoded test ID and
    /// then by encoded test case ID.
    private var _testCasesByEncodedID = [_TestCaseKey: Test.Case]()

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
    ///   - encodedTestID: The previously-encoded ID of the test to find.
    ///
    /// - Returns: An instance of ``Test`` corresponding to `encodedTestID`, or
    ///   `nil` if none was previously passed to ``setTest(_:identifiedBy:)``.
    func test<V>(identifiedBy encodedTestID: ABI.EncodedTest<V>.ID) -> Test? {
      _testsByEncodedID[encodedTestID.stringValue]
    }

    /// Memoize the given test case so it can be looked up later by its encoded
    /// ID.
    ///
    /// - Parameters:
    ///   - testCase: The test case to memoize.
    ///   - encodedTestID: The previously-encoded ID of the test containing
    ///     `testCase`.
    ///   - encodedTestCaseID: The previously-encoded ID of `testCase`.
    mutating func setTestCase<V>(_ testCase: Test.Case, identifiedBy encodedTestID: ABI.EncodedTest<V>.ID, _ encodedTestCaseID: ABI.EncodedTestCase<V>.ID) {
      let key = _TestCaseKey(testID: encodedTestID.stringValue, testCaseID: encodedTestCaseID.stringValue)
      _testCasesByEncodedID[key] = testCase
    }

    /// Find a test case previously passed to ``setTestCase(_:identifiedBy:)``.
    ///
    /// - Parameters:
    ///   - encodedTestID: The previously-encoded ID of the test containing
    ///     the test case to find.
    ///   - encodedTestCaseID: The previously-encoded ID of the test case to
    ///     find.
    ///
    /// - Returns: An instance of ``Test/Case`` corresponding to
    ///   `encodedTestID` and `encodedTestCaseID`, or `nil` if none was
    ///   previously passed to ``setTestCase(_:identifiedBy:)``.
    func testCase<V>(identifiedBy encodedTestID: ABI.EncodedTest<V>.ID, _ encodedTestCaseID: ABI.EncodedTestCase<V>.ID) -> Test.Case? {
      let key = _TestCaseKey(testID: encodedTestID.stringValue, testCaseID: encodedTestCaseID.stringValue)
      return _testCasesByEncodedID[key]
    }
  }
}
#endif

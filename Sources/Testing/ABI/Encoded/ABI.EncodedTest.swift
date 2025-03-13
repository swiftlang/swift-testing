//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension ABI {
  /// A type implementing the JSON encoding of ``Test`` for the ABI entry point
  /// and event stream output.
  ///
  /// The properties and members of this type are documented in ABI/JSON.md.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  struct EncodedTest<V>: Sendable where V: ABI.Version {
    /// An enumeration describing the various kinds of test.
    enum Kind: String, Sendable {
      /// A test suite.
      case suite

      /// A test function.
      case function
    }

    /// The kind of test.
    var kind: Kind

    /// The programmatic name of the test, such as its corresponding Swift
    /// function or type name.
    var name: String

    /// The developer-supplied human-readable name of the test.
    var displayName: String?

    /// The source location of this test.
    var sourceLocation: EncodedSourceLocation<V>

    /// A type implementing the JSON encoding of ``Test/ID`` for the ABI entry
    /// point and event stream output.
    struct ID: Sendable {
      /// The string value representing the corresponding test ID.
      var stringValue: String

      init(encoding testID: borrowing Test.ID) {
        stringValue = String(describing: copy testID)
      }
    }

    /// The unique identifier of this test.
    var id: ID

    /// The test cases in this test, if it is a parameterized test function.
    ///
    /// - Warning: Test cases are not yet part of the JSON schema.
    var _testCases: [EncodedTestCase<V>]?

    /// Whether or not the test is parameterized.
    ///
    /// If this instance represents a test _suite_, the value of this property
    /// is `nil`.
    var isParameterized: Bool?

    /// The tags associated with the test.
    ///
    /// - Warning: Tags are not yet part of the JSON schema.
    ///
    /// @Metadata {
    ///   @Available("Swift Testing ABI", introduced: 1)
    /// }
    var _tags: [String]?

    init(encoding test: borrowing Test) {
      if test.isSuite {
        kind = .suite
      } else {
        kind = .function
        let testIsParameterized = test.isParameterized
        isParameterized = testIsParameterized
        if testIsParameterized {
          _testCases = test.uncheckedTestCases?.map(EncodedTestCase.init(encoding:))
        }
      }
      name = test.name
      displayName = test.displayName
      sourceLocation = EncodedSourceLocation(encoding: test.sourceLocation)
      id = ID(encoding: test.id)

      if V.versionNumber >= ABI.v1.versionNumber {
        let tags = test.tags
        if !tags.isEmpty {
          _tags = tags.map(String.init(describing:))
        }
      }
    }
  }
}

extension ABI {
  /// A type implementing the JSON encoding of ``Test/Case`` for the ABI entry
  /// point and event stream output.
  ///
  /// The properties and members of this type are documented in ABI/JSON.md.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  ///
  /// - Warning: Test cases are not yet part of the JSON schema.
  struct EncodedTestCase<V>: Sendable where V: ABI.Version {
    var id: String
    var displayName: String

    init(encoding testCase: borrowing Test.Case) {
      // TODO: define an encodable form of Test.Case.ID
      id = String(describing: testCase.id)
      displayName = testCase.arguments.lazy
        .map(\.value)
        .map(String.init(describingForTest:))
        .joined(separator: ", ")
    }
  }
}

// MARK: - Decodable

extension ABI.EncodedTest: Decodable {}
extension ABI.EncodedTest.Kind: Decodable {}
extension ABI.EncodedTest.ID: Decodable {
  init(from decoder: any Decoder) throws {
    stringValue = try String(from: decoder)
  }
}
extension ABI.EncodedTestCase: Decodable {}

// MARK: - JSON.Serializable

extension ABI.EncodedTest: JSON.Serializable {
  func makeJSON() throws -> some Collection<UInt8> {
    var dict = JSON.HeterogenousDictionary()

    try dict.updateValue(kind, forKey: "kind")
    try dict.updateValue(name, forKey: "name")
    if let displayName {
      try dict.updateValue(displayName, forKey: "displayName")
    }
    try dict.updateValue(sourceLocation, forKey: "sourceLocation")
    try dict.updateValue(id, forKey: "id")
    if let _testCases {
      try dict.updateValue(_testCases, forKey: "_testCases")
    }
    if let isParameterized {
      try dict.updateValue(isParameterized, forKey: "isParameterized")
    }
    if let _tags {
      try dict.updateValue(_tags, forKey: "_tags")
    }

    return try dict.makeJSON()
  }
}
extension ABI.EncodedTest.Kind: JSON.Serializable {}

extension ABI.EncodedTest.ID: JSON.Serializable {
  func makeJSON() throws -> some Collection<UInt8> {
    try stringValue.makeJSON()
  }
}

extension ABI.EncodedTestCase: JSON.Serializable {
  func makeJSON() throws -> some Collection<UInt8> {
    var dict = JSON.HeterogenousDictionary()

    try dict.updateValue(id, forKey: "id")
    try dict.updateValue(displayName, forKey: "displayName")

    return try dict.makeJSON()
  }
}

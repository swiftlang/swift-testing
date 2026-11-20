//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_ABI_JSON_SCHEMA
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
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.6)
  /// }
  public struct EncodedTestCase<V>: Sendable where V: ABI.Version {
    /// The ID of the test containing this test case.
    var testID: EncodedTest<V>.ID

    /// A type describing an argument to a test case.
    struct Argument: Sendable {
      /// A description of the argument.
      var value: String

      /// The type of the argument, if available.
      var type: EncodedTypeInfo<V>?
    }

    /// The arguments to this test case.
    var arguments: [Argument]

    /// A type implementing the JSON encoding of ``Test/Case/ID`` for the ABI
    /// entry point and event stream output.
    struct ID {
      /// The string value representing the corresponding test case ID.
      var stringValue: String

      init(encoding testCaseID: borrowing Test.Case.ID) {
        stringValue = String(describing: copy testCaseID)
      }
    }

    var id: ID

    /// Whether or not this test case's ID is stable.
    var hasStableID: Bool
  }
}

// MARK: - Codable, JSON.Encodable

#if !SWT_NO_CODABLE
extension ABI.EncodedTestCase: Codable {
  /// The keys used to encode ``ABI/EncodedTestCase``.
  private enum _CodingKeys: String, CodingKey {
    case testID
    case arguments
    case id
    case hasStableID
  }

  public func encode(to encoder: any Encoder) throws(any Error) {
    try encoder.encodeJSONEncodableValue(self)
  }
}

extension ABI.EncodedTestCase.Argument: Codable {
  public func encode(to encoder: any Encoder) throws(any Error) {
    try encoder.encodeJSONEncodableValue(self)
  }
}

extension ABI.EncodedTestCase.ID: Codable {
  func encode(to encoder: any Encoder) throws(any Error) {
    try stringValue.encode(to: encoder)
  }

  init(from decoder: any Decoder) throws(any Error) {
    stringValue = try String(from: decoder)
  }
}
#endif

extension ABI.EncodedTestCase: JSON.Encodable {
  func jsonValue(in context: borrowing JSON.EncodingContext) -> JSON.Value {
    var result = [String: JSON.Value]()

    result["testID"] = testID.stringValue.jsonValue(in: context)
    result["arguments"] = arguments.jsonValue(in: context)
    result["id"] = id.stringValue.jsonValue(in: context)
    result["hasStableID"] = hasStableID.jsonValue(in: context)

    return .object(result)
  }
}

extension ABI.EncodedTestCase.Argument: JSON.Encodable {
  func jsonValue(in context: borrowing JSON.EncodingContext) -> JSON.Value {
    var result = [String: JSON.Value]()

    result["value"] = value.jsonValue(in: context)
    result["type"] = type?.jsonValue(in: context)

    return .object(result)
  }
}

// MARK: - Conversion to/from library types

extension ABI.EncodedTestCase {
  init(encoding testCase: borrowing Test.Case, of test: borrowing Test) {
    guard let arguments = testCase.arguments else {
      preconditionFailure("Attempted to initialize an instance of 'ABI.EncodedTestCase' encoding a test case which is not parameterized: \(testCase). \(fileABugMessage)")
    }

    self.testID = ABI.EncodedTest<V>.ID(encoding: test.id)
    self.arguments = arguments.map { argument in
      Argument(
        value: String(describingForTest: argument),
        type: ABI.EncodedTypeInfo<V>(encoding: argument.typeInfo)
      )
    }
    let testCaseID = testCase.id
    self.id = ID(encoding: testCaseID)
    self.hasStableID = testCaseID.isStable
  }
}

@_spi(ForToolsIntegrationOnly)
extension Test.Case {
  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - test: The encoded test to initialize this instance from.
  ///
  /// The resulting instance of ``Test`` cannot be run; attempting to do so will
  /// throw an error.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.6)
  /// }
  public init?<V>(decoding testCase: ABI.EncodedTestCase<V>, in context: inout ABI.Context) {
    guard let test = context.test(identifiedBy: testCase.testID) else {
      return nil
    }
    self.init(
      values: testCase.arguments.map(Test.Case.Argument.Value.init(decoding:)),
      parameters: test.parameters ?? []
    ) {
      throw APIMisuseError(description: "This instance of 'Test.Case' was synthesized at runtime and cannot be run directly.")
    }

    // Memoize the test by its ID so we can look it up later when decoding
    // events that might need it.
    context.setTestCase(self, identifiedBy: testCase.testID, testCase.id)
  }
}
#endif

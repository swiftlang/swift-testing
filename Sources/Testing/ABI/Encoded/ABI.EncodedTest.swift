//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift project authors
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
  /// You can use this type and its conformance to [`Codable`](https://developer.apple.com/documentation/swift/codable),
  /// when integrating the testing library with development tools. It is not
  /// part of the testing library's public interface.
  public struct EncodedTest<V>: Sendable where V: ABI.Version {
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
    struct ID: Codable {
      /// The string value representing the corresponding test ID.
      var stringValue: String

      init(encoding testID: borrowing Test.ID) {
        stringValue = String(describing: copy testID)
      }

      func encode(to encoder: any Encoder) throws {
        try stringValue.encode(to: encoder)
      }

      init(from decoder: any Decoder) throws {
        stringValue = try String(from: decoder)
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

    /// A type describing a parameter to a parameterized test function.
    ///
    /// - Warning: Parameter info is not yet part of the JSON schema.
    struct Parameter: Sendable, Codable {
      /// The name of the parameter, if known.
      var name: String?

      /// The fully-qualified name of the parameter's type.
      var typeName: String
    }

    /// Information about the parameters to this test.
    ///
    /// If this instance does not represent a _parameterized test function_, the
    /// value of this property is `nil`.
    ///
    /// - Warning: Parameter info is not yet part of the JSON schema.
    var _parameters: [Parameter]?

    /// An equivalent of ``tags`` that preserves ABIv6.3 support.
    var _tags: [String]?

    /// The tags associated with the test.
    ///
    /// @Metadata {
    ///   @Available(Swift, introduced: 6.4)
    /// }
    var tags: [String]?

    /// The bugs associated with the test.
    ///
    /// @Metadata {
    ///   @Available(Swift, introduced: 6.4)
    /// }
    var bugs: [Bug]?

    /// The time limits associated with the test.
    ///
    /// @Metadata {
    ///   @Available(Swift, introduced: 6.4)
    /// }
    var timeLimit: Double?
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
      guard let arguments = testCase.arguments else {
        preconditionFailure("Attempted to initialize an EncodedTestCase encoding a test case which is not parameterized: \(testCase). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
      }

      // TODO: define an encodable form of Test.Case.ID
      id = String(describing: testCase.id)
      displayName = arguments.lazy
        .map(\.value)
        .map(String.init(describingForTest:))
        .joined(separator: ", ")
    }
  }
}

// MARK: - Codable

extension ABI.EncodedTest: Codable {}
extension ABI.EncodedTest.Kind: Codable {}
extension ABI.EncodedTestCase: Codable {}

// MARK: - Conversion to/from library types

extension ABI.EncodedTest {
  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - test: The test to initialize this instance from.
  public init(encoding test: borrowing Test) {
    if test.isSuite {
      kind = .suite
    } else {
      kind = .function
      isParameterized = test.isParameterized
    }
    name = test.name
    displayName = test.displayName
    sourceLocation = ABI.EncodedSourceLocation(encoding: test.sourceLocation)
    id = ID(encoding: test.id)

    // Experimental fields
    if V.includesExperimentalFields {
      if isParameterized == true {
        _testCases = test.uncheckedTestCases?.map(ABI.EncodedTestCase.init(encoding:))
        _parameters = test.parameters?.map { parameter in
          Parameter(
            name: parameter.secondName ?? parameter.firstName,
            typeName: parameter.typeInfo.fullyQualifiedName
          )
        }
      }
      let tags = test.tags
      if !tags.isEmpty {
        self._tags = tags.map(String.init(describing:))
      }
    }

    if V.versionNumber >= ABI.v6_4.versionNumber {
      self.tags = test.tags.sorted().map { tag in
        switch tag.kind {
        case .staticMember(let value): value
        }
      }
      let bugs = test.associatedBugs
      if !bugs.isEmpty {
        self.bugs = bugs
      }
      self.timeLimit = test.timeLimit.map { $0 / .seconds(1) }
    }
  }
}

@_spi(ForToolsIntegrationOnly)
extension Test {
  private static func _makeTypeInfo<V>(for test: ABI.EncodedTest<V>) -> TypeInfo? {
    // Find the module name, which for XCTest compatibility is split from the
    // rest of the test ID by a period character instead of a slash character.
    let testID = test.id.stringValue
    let splitByPeriod = rawIdentifierAwareSplit(testID, separator: ".", maxSplits: 1)
    var testIDComponents = rawIdentifierAwareSplit(testID, separator: "/")
    guard let moduleName = splitByPeriod.first,
          let firstComponent = testIDComponents.first,
          moduleName.endIndex < firstComponent.endIndex else {
      // The string wasn't structured as expected for a Swift Testing or XCTest
      // test ID.
      return nil
    }

    // Replace the first component string, which is currently shaped like
    // "ModuleName.TypeName", with ["ModuleName", "TypeName"]
    let secondTestIDComponent = testID[moduleName.endIndex ..< firstComponent.endIndex].dropFirst()
    testIDComponents[0] = moduleName
    testIDComponents.insert(secondTestIDComponent, at: 1)

    if test.kind == .function {
      if let lastComponent = testIDComponents.last,
         lastComponent.utf8.first != UInt8(ascii: "`"),
         lastComponent.utf8.contains(UInt8(ascii: ":")) {
        // The last component of the test ID (when split by slash characters)
        // appears to be a source location. Remove it as it's not part of the
        // suite type.
        testIDComponents.removeLast()
      }

      // The last component of the test ID is the name of the test function.
      // Remove that too.
      testIDComponents.removeLast()
    }

    // Recombine the module name with the rest of the test ID to produce the
    // fully-qualified type name. Join everything by slashes.
    return TypeInfo(fullyQualifiedNameComponents: testIDComponents.map(String.init))
  }

  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - test: The encoded test to initialize this instance from.
  ///
  /// The resulting instance of ``Test`` cannot be run; attempting to do so will
  /// throw an error.
  public init?<V>(decoding test: ABI.EncodedTest<V>) {
    let sourceLocation = SourceLocation(decoding: test.sourceLocation) ?? .unknown
    let typeInfo = Self._makeTypeInfo(for: test)

    // Construct the (partial) list of traits available in the encoded test.
    // Note we do not try to encode _all_ traits because many trait types simply
    // cannot be represented as JSON.
    var traits = [any Trait]()
    if let tags = test.tags ?? test._tags {
      let tags = tags.map(Tag.init(userProvidedStringValue:))
      traits += [Tag.List(tags: tags)]
    }
    if let bugs = test.bugs {
      traits += bugs
    }
    if let timeLimit = test.timeLimit {
      traits += [TimeLimitTrait(timeLimit: .seconds(timeLimit))]
    }

    switch test.kind {
    case .suite:
      guard let typeInfo else {
        return nil
      }
      self.init(
        displayName: test.displayName,
        traits: traits,
        sourceLocation: sourceLocation,
        containingTypeInfo: typeInfo,
        isSynthesized: true
      )
    case .function:
      let parameters = test._parameters.map { parameters in
        parameters.enumerated().map { i, parameter in
          Testing.Test.Parameter(
            index: i,
            firstName: parameter.name ?? "_",
            typeInfo: TypeInfo(fullyQualifiedName: parameter.typeName, mangledName: nil)
          )
        }
      }

      self.init(
        name: test.name,
        displayName: test.displayName,
        traits: traits,
        sourceBounds: __SourceBounds(lowerBoundOnly: sourceLocation),
        containingTypeInfo: typeInfo,
        xcTestCompatibleSelector: nil,
        testCases: { () -> Test.Case.Generator<CollectionOfOne<Void>> in
          throw APIMisuseError(description: "This instance of 'Test' was synthesized at runtime and cannot be run directly.")
        },
        parameters: parameters ?? []
      )
    }
  }
}
